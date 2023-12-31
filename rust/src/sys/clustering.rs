use anyhow::anyhow;

use crate::errors::CumlError;

use super::{
    bindings::{AgglomerativeClusteringFit, DbscanFit, KmeansFit},
    device_resource::DeviceResource,
};

pub fn agglomerative_clustering(
    resource: &DeviceResource,
    data: &[f32],
    num_row: usize,
    num_col: usize,
    pairwise_conn: bool,
    metric: i32,
    n_neighbors: i32,
    init_n_clusters: i32,
    labels: &mut [i32],
    children: &mut [i32],
) -> Result<i32, CumlError> {
    let mut num_cluster = 0i32;

    let result = unsafe {
        AgglomerativeClusteringFit(
            resource.handle,
            data.as_ptr() as *const f32,
            num_row,
            num_col,
            pairwise_conn,
            metric as i32,
            n_neighbors,
            init_n_clusters,
            &mut num_cluster,
            labels.as_mut_ptr() as *mut i32,
            children.as_mut_ptr() as *mut i32,
        )
    };

    if result != 0 {
        Err(anyhow!("fail to AgglomerativeClusteringFit"))?
    }

    Ok(num_cluster)
}

pub fn dbscan(
    resource: &DeviceResource,
    data: &[f32],
    num_row: usize,
    num_col: usize,
    min_pts: i32,
    eps: f64,
    metric: i32,
    max_bytes_per_batch: usize,
    verbosity: i32,
    labels: &mut [i32],
) -> Result<(), CumlError> {
    let result = unsafe {
        DbscanFit(
            resource.handle,
            data.as_ptr() as *const f32,
            num_row,
            num_col,
            min_pts,
            eps,
            metric,
            max_bytes_per_batch,
            verbosity,
            labels.as_mut_ptr() as *mut i32,
        )
    };

    if result != 0 {
        Err(anyhow!("fail to dbscan"))?
    }

    Ok(())
}

pub fn kmeans(
    resource: &DeviceResource,
    data: &[f32],
    num_row: usize,
    num_col: usize,
    k: i32,
    max_iter: i32,
    tol: f64,
    init_method: i32,
    metric: i32,
    seed: i32,
    verbosity: i32,
    labels: &mut [i32],
    centroids: &mut [f32],
) -> Result<(f32, i32), CumlError> {
    let mut inertia = 0f32;
    let mut n_iter = 0i32;

    let num_row = num_row as i32;
    let num_col = num_col as i32;

    let result = unsafe {
        KmeansFit(
            resource.handle,
            data.as_ptr() as *const f32,
            num_row,
            num_col,
            k,
            max_iter,
            tol,
            init_method,
            metric,
            seed,
            verbosity,
            labels.as_mut_ptr() as *mut i32,
            centroids.as_mut_ptr() as *mut f32,
            &mut inertia,
            &mut n_iter,
        )
    };

    if result != 0 {
        Err(anyhow!("fail to dbscan"))?
    }

    Ok((inertia, n_iter))
}
