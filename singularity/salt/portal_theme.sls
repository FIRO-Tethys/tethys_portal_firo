{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set STATIC_ROOT = salt['environ.get']('STATIC_ROOT') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set THEME_NAME = salt['environ.get']('THEME_NAME') %}



{% set TETHYS_SITE_VAR_LIST = ['SITE_TITLE', 'FAVICON', 'BRAND_TEXT', 'BRAND_IMAGE', 'BRAND_IMAGE_HEIGHT',
                               'BRAND_IMAGE_WIDTH', 'BRAND_IMAGE_PADDING', 'APPS_LIBRARY_TITLE', 'PRIMARY_COLOR',
                               'SECONDARY_COLOR', 'PRIMARY_TEXT_COLOR', 'PRIMARY_TEXT_HOVER_COLOR',
                               'SECONDARY_TEXT_COLOR', 'SECONDARY_TEXT_HOVER_COLOR', 'BACKGROUND_COLOR',
                               'COPYRIGHT', 'HERO_TEXT', 'BLURB_TEXT', 'FEATURE_1_HEADING', 'FEATURE_1_BODY',
                               'FEATURE_1_IMAGE', 'FEATURE_2_HEADING', 'FEATURE_2_BODY', 'FEATURE_2_IMAGE',
                               'FEATURE_3_HEADING', 'FEATURE_3_BODY', 'FEATURE_3_IMAGE', 'CALL_TO_ACTION',
                               'CALL_TO_ACTION_BUTTON', 'PORTAL_BASE_CSS', 'HOME_PAGE_CSS', 'APPS_LIBRARY_CSS',
                               'ACCOUNTS_BASE_CSS', 'LOGIN_CSS', 'REGISTER_CSS', 'USER_BASE_CSS', 'HOME_PAGE_TEMPLATE',
                               'APPS_LIBRARY_TEMPLATE', 'LOGIN_PAGE_TEMPLATE', 'REGISTER_PAGE_TEMPLATE',
                               'USER_PAGE_TEMPLATE', 'USER_SETTINGS_PAGE_TEMPLATE'] %}

{% set TETHYS_SITE_CONTENT_LIST = [] %}

{% for ARG in TETHYS_SITE_VAR_LIST %}
  {% if salt['environ.get'](ARG) %}
    {% set ARG_KEY = ['--', ARG.replace('_', '-')|lower]|join %}
    {% set CONTENT = [ARG_KEY, salt['environ.get'](ARG)|quote]|join(' ') %}
    {% do TETHYS_SITE_CONTENT_LIST.append(CONTENT) %}
  {% endif %}
{% endfor %}

{% set TETHYS_SITE_CONTENT = TETHYS_SITE_CONTENT_LIST|join(' ') %}



Move_Custom_Theme_Files_to_Static_Root:
  cmd.run:
    - name: ln -s {{ TETHYS_HOME }}/{{ THEME_NAME }} {{ STATIC_ROOT }}
    - shell: /bin/bash
    - unless: test -L {{ STATIC_ROOT }}

Move_Custom_Template_Files_to_Tethys_Apps:
  cmd.run:
    - name: ln -s {{ TETHYS_HOME }}/{{ THEME_NAME }}/templates/ {{ TETHYS_HOME }}/tethys/tethys_apps/templates/tethys_apps
    - shell: /bin/bash
    - unless: test -L {{ TETHYS_HOME }}/tethys/tethys_apps/templates/tethys_apps

{% if TETHYS_SITE_CONTENT %}
Set_Tethys_Site_Settings:
  cmd.run:
    - name: tethys site {{ TETHYS_SITE_CONTENT }}
    - shell: /bin/bash
{% endif %}

Set_Open_Portal:
  cmd.run:
    - name: tethys settings -s TETHYS_PORTAL_CONFIG.ENABLE_OPEN_SIGNUP true
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/custom_theme_setup_complete" ];"

Flag_Custom_Theme_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/custom_theme_setup_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/custom_theme_setup_complete" ];"