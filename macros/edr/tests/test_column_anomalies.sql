{% test column_anomalies(model, column_name, column_anomalies, timestamp_column, sensitivity, backfill_days, where_expression, time_bucket,anomaly_direction='both', seasonality=none) %}
    -- depends_on: {{ ref('monitors_runs') }}
    -- depends_on: {{ ref('data_monitoring_metrics') }}
    -- depends_on: {{ ref('alerts_anomaly_detection') }}
    -- depends_on: {{ ref('metrics_anomaly_score') }}
    -- depends_on: {{ ref('dbt_run_results') }}
    {%- if execute and flags.WHICH in ['test', 'build'] %}
        {%- if elementary.is_ephemeral_model(model) %}
            {{ exceptions.raise_compiler_error("The test is not supported for ephemeral models, model name: {}".format(model.identifier)) }}
        {%- endif %}

        {% set test_table_name = elementary.get_elementary_test_table_name() %}
        {{ elementary.debug_log('collecting metrics for test: ' ~ test_table_name) }}
        {#- creates temp relation for test metrics -#}
        {% set database_name, schema_name = elementary.get_package_database_and_schema('elementary') %}
        {% set tests_schema_name = elementary.get_elementary_tests_schema(database_name, schema_name) %}

        {#- get column configuration -#}
        {%- set full_table_name = elementary.relation_to_full_name(model) %}
        {%- set model_relation = dbt.load_relation(model) %}
        {% if not model_relation %}
            {{ exceptions.raise_compiler_error("Unable to find table `{}`".format(full_table_name)) }}
        {% endif %}

        {% set model_graph_node = elementary.get_model_graph_node(model_relation) %}
        {% set timestamp_column = elementary.get_timestamp_column(timestamp_column, model_graph_node) %}
        {%- set time_bucket = elementary.get_time_bucket(time_bucket, model) %}

        {% do elementary.validate_seasonality_parameter(seasonality=seasonality, time_bucket=time_bucket, timestamp_column=timestamp_column) %}
        {% set days_back = elementary.get_days_back(seasonality=seasonality) %}
        {% set metric_properties = elementary.construct_metric_properties_dict(timestamp_column=timestamp_column,
                                                                               where_expression=where_expression,
                                                                               time_bucket=time_bucket) %}

        {%- set timestamp_column_data_type = elementary.find_normalized_data_type_for_column(model, metric_properties.timestamp_column) %}
        {{ elementary.debug_log('timestamp_column - ' ~ metric_properties.timestamp_column) }}
        {{ elementary.debug_log('timestamp_column_data_type - ' ~ timestamp_column_data_type) }}
        {%- set is_timestamp = elementary.get_is_column_timestamp(model_relation, metric_properties.timestamp_column, timestamp_column_data_type) %}
        {{ elementary.debug_log('is_timestamp - ' ~ is_timestamp) }}

        {% if metric_properties.timestamp_column and not is_timestamp %}
          {% do exceptions.raise_compiler_error("Column `{}` is not a timestamp.".format(metric_properties.timestamp_column)) %}
        {% endif %}

        {%- set column_obj_and_monitors = elementary.get_column_obj_and_monitors(model, column_name, column_anomalies) -%}
        {%- if not column_obj_and_monitors -%}
            {{ exceptions.raise_compiler_error("Unable to find column `{}` in `{}`".format(column_name, full_table_name)) }}
        {%- endif -%}
        {%- set column_monitors = column_obj_and_monitors['monitors'] -%}
        {%- set column_obj = column_obj_and_monitors['column'] -%}
        {{ elementary.debug_log('column_monitors - ' ~ column_monitors) }}
        {% set backfill_days = elementary.get_test_argument(argument_name='backfill_days', value=backfill_days) %}
        {% if timestamp_column and is_timestamp %}
            {%- set min_bucket_start, max_bucket_end = elementary.get_test_buckets_min_and_max(model_relation=model,
                                                                                    backfill_days=backfill_days,
                                                                                    days_back=days_back,
                                                                                    monitors=column_monitors,
                                                                                    column_name=column_name,
                                                                                    metric_properties=metric_properties) %}
        {%- endif %}
        {{ elementary.debug_log('min_bucket_start - ' ~ min_bucket_start) }}
        {#- execute table monitors and write to temp test table -#}
        {{ elementary.test_log('start', full_table_name, column_name) }}
        {%- set column_monitoring_query = elementary.column_monitoring_query(model_relation,
                                                                             min_bucket_start,
                                                                             max_bucket_end,
                                                                             days_back,
                                                                             column_obj,
                                                                             column_monitors,
                                                                             metric_properties) %}
        {{ elementary.debug_log('column_monitoring_query - \n' ~ column_monitoring_query) }}
        {% set temp_table_relation = elementary.create_elementary_test_table(database_name, tests_schema_name, test_table_name, 'metrics', column_monitoring_query) %}


        {#- calculate anomaly scores for metrics -#}
        {%- set temp_table_name = elementary.relation_to_full_name(temp_table_relation) %}
        {%- set sensitivity = elementary.get_test_argument(argument_name='anomaly_sensitivity', value=sensitivity) %}
        {% do elementary.validate_directional_parameter(anomaly_direction) %}
        {% set anomaly_scores_query = elementary.get_anomaly_scores_query(temp_table_relation,
                                                                          model_graph_node,
                                                                          sensitivity,
                                                                          backfill_days,
                                                                          days_back,
                                                                          column_monitors,
                                                                          column_name,
                                                                          seasonality=seasonality,
                                                                          metric_properties=metric_properties,
                                                                          anomaly_direction=anomaly_direction) %}

        {{ elementary.debug_log('anomaly_score_query - \n' ~ anomaly_scores_query) }}
        {% set anomaly_scores_test_table_relation = elementary.create_elementary_test_table(database_name, tests_schema_name, test_table_name, 'anomaly_scores', anomaly_scores_query) %}
        {{ elementary.test_log('end', full_table_name, column_name) }}

        {{ elementary.get_read_anomaly_scores_query() }}

    {%- else %}

        {#- test must run an sql query -#}
        {{ elementary.no_results_query() }}

    {%- endif %}
{% endtest %}



