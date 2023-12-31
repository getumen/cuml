#ifdef __cplusplus
#define EXTERN_C extern "C"
#include <cstddef>
#else
#define EXTERN_C
#include <stdbool.h>
#include <stdio.h>
#endif

#include "cuml4c/device_resource_handle.h"

EXTERN_C int DbscanFit(
    const DeviceResourceHandle handle,
    const float *x,
    size_t num_row,
    size_t num_col,
    int min_pts,
    double eps,
    int metric,
    size_t max_bytes_per_batch,
    int verbosity,
    int *labels);
