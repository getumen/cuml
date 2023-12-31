#ifdef __cplusplus
#define EXTERN_C extern "C"
#include <cstddef>
#else
#define EXTERN_C
#include <stdbool.h>
#include <stdio.h>
#endif

#include "cuml4c/device_resource_handle.h"

EXTERN_C int KmeansFit(
    const DeviceResourceHandle handle,
    const float *x,
    int num_row,
    int num_col,
    int k,
    int max_iters,
    double tol,
    int init_method,
    int metric,
    int seed,
    int verbosity,
    int *labels,
    float *centroids,
    float *inertia,
    int *n_iter);
