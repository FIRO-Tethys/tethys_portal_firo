{% set ALLOWED_HOSTS = salt['environ.get']('ALLOWED_HOSTS') %}
{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set ALLOWED_CIDR_RANGE = salt['environ.get']('ALLOWED_CIDR_RANGE') %}
{% set PREFIX_URL = salt['environ.get']('PREFIX_URL') %}
{% set FORCE_SCRIPT_NAME = salt['environ.get']('FORCE_SCRIPT_NAME') %}
{% set STATIC_URL = salt['environ.get']('STATIC_URL') %}
{% set MEDIA_URL = salt['environ.get']('MEDIA_URL') %}
{% set WORKSPACES_URL = salt['environ.get']('WORKSPACES_URL') %}
{% set TETHYS_DB_HOST = salt['environ.get']('TETHYS_DB_HOST') %}
{% set TETHYS_DB_PORT = salt['environ.get']('TETHYS_DB_PORT') %}
{% set TETHYS_DB_SUPERUSER = salt['environ.get']('TETHYS_DB_SUPERUSER') %}
{% set TETHYS_DB_SUPERUSER_PASS = salt['environ.get']('TETHYS_DB_SUPERUSER_PASS') %}
{% set PORTAL_SUPERUSER_PASSWORD = salt['environ.get']('PORTAL_SUPERUSER_PASSWORD') %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}
{% set POSTGIS_SERVICE_URL = TETHYS_DB_SUPERUSER + ':' + TETHYS_DB_SUPERUSER_PASS + '@' + TETHYS_DB_HOST + ':' + TETHYS_DB_PORT %}

{% set MULTIPLE_APP_MODE = salt['environ.get']('MULTIPLE_APP_MODE') %}
{% set STANDALONE_APP = salt['environ.get']('STANDALONE_APP') %}

Create_PostGIS_Database_Service:
  cmd.run:
    - name: "tethys services create persistent -n {{ POSTGIS_SERVICE_NAME }} -c {{ POSTGIS_SERVICE_URL }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"


Link_PostGIS_To_Dashboard_App:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} tethysdash:ps_database:primary_db"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"

#Set single mode app
{% if not MULTIPLE_APP_MODE %}
Single_App_Mode:
  cmd.run:
    - name: >
        tethys settings
        --set MULTIPLE_APP_MODE {{ MULTIPLE_APP_MODE }}
        --set STANDALONE_APP {{ STANDALONE_APP }}
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f '{{ TETHYS_PERSIST }}/tethys_services_complete' ]"
{% endif %}

Config_for_Apache:
  cmd.run:
    - name: >
        tethys settings
        --set FORCE_SCRIPT_NAME {{ FORCE_SCRIPT_NAME }}
        --set TETHYS_PORTAL_CONFIG.STATIC_URL {{ STATIC_URL }}
        --set TETHYS_PORTAL_CONFIG.MEDIA_URL {{ MEDIA_URL }}
        --set TETHYS_PORTAL_CONFIG.WORKSPACES_URL {{ WORKSPACES_URL }}
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f '{{ TETHYS_PERSIST }}/tethys_services_complete' ]"


Flag_Tethys_Services_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/tethys_services_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"