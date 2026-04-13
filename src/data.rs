use crate::cli::DataOptions;

pub fn query_pairs(options: &DataOptions) -> Vec<(String, String)> {
    let mut query = Vec::new();
    if options.include_trashed {
        query.push(("include_trashed".to_string(), "true".to_string()));
    }
    if options.include_deleted {
        query.push(("include_deleted".to_string(), "true".to_string()));
    }
    if options.unwrap {
        query.push(("unwrap".to_string(), "true".to_string()));
    }
    if let Some(select) = &options.select {
        query.push(("select".to_string(), select.clone()));
    }
    if let Some(where_filter) = &options.r#where {
        query.push(("where".to_string(), where_filter.clone()));
    }
    if let Some(stat) = options.stat {
        query.push(("stat".to_string(), stat.to_string()));
    }
    if let Some(access) = options.access {
        query.push(("access".to_string(), access.to_string()));
    }
    if options.permanent {
        query.push(("permanent".to_string(), "true".to_string()));
    }
    if options.upsert {
        query.push(("upsert".to_string(), "true".to_string()));
    }
    query
}
