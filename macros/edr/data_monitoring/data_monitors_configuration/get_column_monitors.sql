{% macro get_column_monitors(model, column_name, column_tests=none) %}
    {%- set column_objects = adapter.get_columns_in_relation(model) -%}
    {%- set column_monitors = [] -%}
    {%- for column_obj in column_objects %}
        {%- if column_obj.name | lower == column_name | lower %}
            {%- do column_monitors.extend(elementary.column_monitors_by_type(column_obj.dtype, column_tests=none)) %}
        {%- endif %}
    {%- endfor %}
    {{ return(column_monitors) }}
{% endmacro %}


{% macro get_all_columns_monitors(model_relation, column_tests=none) %}

    {%- set columns_config = [] %}
    {%- set columns_from_relation = adapter.get_columns_in_relation(model_relation) -%}

    {%- for column in columns_from_relation %}
        {%- set column_normalized_type = elementary.normalize_data_type(column['dtype']) %}
        {%- set column_monitors = elementary.column_monitors_by_type(column_normalized_type, column_tests) %}
        {%- set column_item = {'column_name': column['column'], 'monitors': column_monitors} %}
        {%- do columns_config.append(column_item) -%}
    {% endfor %}

    {{ return(columns_config) }}

{% endmacro %}


{% macro column_monitors_by_type(data_type, column_tests=none) %}

    {%- set normalized_data_type = elementary.normalize_data_type(data_type) %}

    {%- set default_all_types = elementary.get_config_var('edr_monitors')['column_any_type'] | list %}
    {%- set default_numeric_monitors = elementary.get_config_var('edr_monitors')['column_numeric'] | list %}
    {%- set default_string_monitors = elementary.get_config_var('edr_monitors')['column_string'] | list %}

    {# if column_tests is null, default is to use all relevant monitors for this data type #}
    {%- if column_tests is defined and column_tests is not none and column_tests | length > 0 %}
        {%- set monitors_list = column_tests %}
    {%- else %}
        {% set monitors_list = [] %}
        {% do monitors_list.extend(default_all_types) %}
        {% do monitors_list.extend(default_numeric_monitors) %}
        {% do monitors_list.extend(default_string_monitors) %}
    {%- endif %}

    {%- set column_monitors = [] %}

    {%- set all_types_intersect = elementary.lists_intersection(monitors_list, default_all_types) %}
    {%- for monitor in all_types_intersect %}
        {{ column_monitors.append(monitor) }}
    {%- endfor %}

    {%- if normalized_data_type == 'numeric' %}
        {%- set numeric_intersect = elementary.lists_intersection(monitors_list, default_numeric_monitors) %}
        {%- for monitor in numeric_intersect %}
            {{ column_monitors.append(monitor) }}
        {%- endfor %}
    {%- endif %}

    {%- if normalized_data_type == 'string' %}
        {%- set string_intersect = elementary.lists_intersection(monitors_list, default_string_monitors) %}
        {%- for monitor in string_intersect %}
            {{ column_monitors.append(monitor) }}
        {%- endfor %}
    {%- endif %}

    {{ return(column_monitors) }}

{% endmacro %}

{% macro all_column_monitors() %}
    {%- set all_column_monitors = [] %}
    {%- set numeric = elementary.get_config_var('edr_monitors')['column_numeric'] %}
    {%- do all_column_monitors.extend(elementary.get_config_var('edr_monitors')['column_any_type']) -%}
    {%- do all_column_monitors.extend(elementary.get_config_var('edr_monitors')['column_string']) -%}
    {%- do all_column_monitors.extend(elementary.get_config_var('edr_monitors')['column_numeric']) -%}
    {{ return(all_column_monitors) }}
{% endmacro %}
