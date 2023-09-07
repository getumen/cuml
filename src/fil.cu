#include "cuml4c/fil.h"

#include <rmm/device_uvector.hpp>
#include <raft/core/handle.hpp>
#include <raft/util/cudart_utils.hpp>
#include <treelite/c_api.h>
#include <cuml/fil/fil.h>

#include <memory>
#include <string>

namespace
{

  enum class ModelType
  {
    XGBoost,
    XGBoostJSON,
    LightGBM
  };

  struct FILModel
  {
    __host__ FILModel(std::unique_ptr<raft::handle_t> handle,
                      std::unique_ptr<ML::fil::forest32_t> forest,
                      size_t const num_classes,
                      size_t const num_features)
        : handle_(std::move(handle)), forest_(std::move(forest)),
          numClasses_(num_classes), numFeatures_(num_features) {}

    std::unique_ptr<raft::handle_t> const handle_;
    std::unique_ptr<ML::fil::forest32_t> forest_;
    size_t const numClasses_;
    size_t const numFeatures_;
  };

  __host__ int treeliteLoadModel(ModelType const model_type,
                                 char const *filename,
                                 ModelHandle *model_handle)
  {
    switch (model_type)
    {
    case ModelType::XGBoost:
      return TreeliteLoadXGBoostModel(filename, model_handle);
    case ModelType::XGBoostJSON:
      return TreeliteLoadXGBoostJSON(filename, model_handle);
    case ModelType::LightGBM:
      return TreeliteLoadLightGBMModel(filename, model_handle);
    }

    // unreachable
    return -1;
  }

} // namespace

__host__ int FILLoadModel(
    int model_type,
    const char *filename,
    int algo,
    bool classification,
    float threshold,
    int storage_type,
    int blocks_per_sm,
    int threads_per_tree,
    int n_items,
    FILModelHandle *out)
{

  ModelHandle model_handle;
  {
    auto const res = treeliteLoadModel(
        /*model_type=*/static_cast<ModelType>(model_type),
        /*filename=*/filename,
        &model_handle);
    if (res < 0)
    {
      return FIL_FAIL_TO_LOAD_MODEL;
    }
  }

  size_t num_features = 0;
  {
    auto res = TreeliteQueryNumFeature(model_handle, &num_features);
    if (res < 0)
    {
      return FIL_FAIL_TO_GET_NUM_FEATURE;
    }
  }

  size_t num_classes = 0;
  if (classification)
  {
    auto res = TreeliteQueryNumClass(model_handle, &num_classes);
    if (res < 0)
    {
      return FIL_FAIL_TO_GET_NUM_CLASS;
    }

    // Treelite returns 1 as number of classes for binary classification.
    num_classes = std::max(num_classes, size_t(2));
  }

  ML::fil::treelite_params_t params;
  params.algo = static_cast<ML::fil::algo_t>(algo);
  params.output_class = classification;
  params.threshold = threshold;
  params.storage_type = static_cast<ML::fil::storage_type_t>(storage_type);
  params.blocks_per_sm = blocks_per_sm;
  params.output_class = classification;
  params.threads_per_tree = threads_per_tree;
  params.n_items = n_items;
  params.pforest_shape_str = nullptr;
  params.precision = ML::fil::precision_t::PRECISION_FLOAT32;

  auto handle = std::make_unique<raft::handle_t>();

  ML::fil::forest_variant f;

  ML::fil::from_treelite(
      /*handle=*/*handle,
      /*pforest=*/&f,
      /*model=*/model_handle,
      /*tl_params=*/&params);

  auto forest = std::make_unique<ML::fil::forest32_t>(std::move(std::get<ML::fil::forest32_t>(f)));

  auto model = std::make_unique<FILModel>(
      /*handle=*/std::move(handle),
      std::move(forest),
      num_classes,
      num_features);

  *out = static_cast<FILModelHandle>(model.release());

  {
    auto res = TreeliteFreeModel(model_handle);
    if (res < 0)
    {
      return FIL_FAIL_TO_FREE_MODEL;
    }
  }

  return FIL_SUCCESS;
}

__host__ int FILFreeModel(
    FILModelHandle model)
{
  auto model_ptr = static_cast<FILModel const *>(model);
  ML::fil::free(*model_ptr->handle_, *model_ptr->forest_);
  delete model_ptr;
  return FIL_SUCCESS;
}

__host__ int FILGetNumClasses(
    FILModelHandle model,
    size_t *out)
{
  auto const model_ptr = static_cast<FILModel const *>(model);
  *out = model_ptr->numClasses_;
  return FIL_SUCCESS;
}

__host__ int FILPredict(
    FILModelHandle model,
    const float *x,
    size_t num_row,
    bool output_class_probabilities,
    float *preds)
{

  auto fil_model = static_cast<FILModel *>(model);

  const auto &handle = *fil_model->handle_;

  if (output_class_probabilities && fil_model->numClasses_ == 0)
  {
    return FIL_INVALID_ARGUMENT;
  }

  auto d_x = rmm::device_uvector<float>(
      fil_model->numFeatures_ * num_row,
      handle.get_stream());

  raft::update_device(d_x.data(),
                      x,
                      fil_model->numFeatures_ * num_row,
                      handle.get_stream());

  auto pred_size = output_class_probabilities
                       ? fil_model->numClasses_ * num_row
                       : num_row;

  auto d_preds = rmm::device_uvector<float>(
      pred_size,
      handle.get_stream());

  ML::fil::predict(/*h=*/handle,
                   /*f=*/*fil_model->forest_,
                   /*preds=*/d_preds.begin(),
                   /*data=*/d_x.begin(),
                   /*num_rows=*/num_row,
                   /*predict_proba=*/output_class_probabilities);

  raft::update_host(preds,
                    d_preds.begin(),
                    d_preds.size(),
                    handle.get_stream());

  handle.get_stream().synchronize();

  return FIL_SUCCESS;
}
