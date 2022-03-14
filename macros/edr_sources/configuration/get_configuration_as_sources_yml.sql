{% macro get_configuration_as_sources_yml() %}
    {% if execute %}
        {% set edr_sources_database = elementary.get_edr_sources_db() %}
        {% set edr_sources_schema = elementary.get_edr_sources_schema() %}
        {%- set table_monitors_config = adapter.get_relation(database=edr_sources_database,
                                                             schema=edr_sources_schema,
                                                             identifier='table_monitors_config') -%}
        {%- set column_monitors_config = adapter.get_relation(database=edr_sources_database,
                                                              schema=edr_sources_schema,
                                                              identifier='column_monitors_config') -%}
        {% set table_monitors_config_query %}
            select * from {{ table_monitors_config.include(database=True, schema=True, identifier=True) }} table_config left join
                          {{ column_monitors_config.include(database=True, schema=True, identifier=True) }} column_config on
                          (table_config.database_name = column_config.database_name and table_config.schema_name = column_config.schema_name
                           and table_config.table_name = column_config.table_name)
                where table_monitored = true
        {% endset %}
        {% set table_configs = run_query(table_monitors_config_query) %}
        {% set tables_dict = {} %}
        {% for table_config in table_configs.rows %}
            {% set table_database_name = table_config['DATABASE_NAME'] %}
            {% set table_schema_name = table_config['SCHEMA_NAME'] %}
            {% set table_name = table_config['TABLE_NAME'] %}
            {% set table_monitors = table_config['TABLE_MONITORS'] %}
            {% set columns_monitored = table_config['COLUMNS_MONITORED'] %}
            {% set column_name = table_config['COLUMN_NAME'] %}
            {% set column_monitors = table_config['COLUMN_MONITORS'] %}
            {% if table_monitors %}
                {% set table_monitors = fromjson(table_monitors) %}
            {% endif %}
            {% if column_monitors %}
                {% set column_monitors = fromjson(column_monitors) %}
            {% endif %}

            {% set table_key = table_database_name ~ '.' ~ table_schema_name ~ '.' ~ table_name %}
            {% set table_dict = tables_dict.get(table_key) %}
            {% if not table_dict %}
                {% set table_dict = {'name': table_name,
                                     'tests': {'elementary.table_anomalies': {
                                                    'table_tests': table_monitors,
                                                    'tags': ['elementary']}},
                                     'columns': []
                                     } %}
            {% endif %}
            {% if column_name and columns_monitored %}
                {% do table_dict['columns'].append({'name': column_name,
                                                    'tests': {'elementary.column_anomalies': {
                                                                    'column_tests': column_monitors,
                                                                    'tags': ['elementary']}}}) %}
            {% endif %}
            {% do tables_dict.update({table_key: table_dict}) %}
        {% endfor %}
        {% set sources_dict = {} %}
        {% for table_key, table_dict in tables_dict.items() %}
            {% set table_database_name, table_schema_name, table_name = table_key.split('.') %}
            {% set source_key = table_database_name ~ '.' ~ table_schema_name %}
            {% set source_dict = sources_dict.get(source_key) %}
            {% if not source_dict %}
                {% set source_dict = {'name': table_schema_name, 'database': table_database_name, 'tables': []} %}
            {% endif %}
            {% do source_dict['tables'].append(table_dict) %}
            {% do sources_dict.update({source_key: source_dict}) %}
        {% endfor %}
        {% set sources_yml_dict = {'version': 2, 'sources': sources_dict.values() | list} %}
        {% set sources_yml = toyaml(sources_yml_dict) %}
        {% do elementary.edr_log(sources_yml) %}
    {% endif %}
{% endmacro %}
