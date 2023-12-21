{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}

{% set APP_INSTALLER_USER_EMAIL = salt['environ.get']('APP_INSTALLER_USER_EMAIL') %}
{% set APP_INSTALLER_USER_NAME = salt['environ.get']('APP_INSTALLER_USER_NAME') %}
{% set APP_STORE_SERVER_PASS = salt['environ.get']('APP_STORE_SERVER_PASS') %}
{% set APP_STORE_STORES_SETTINGS = "'" + salt['environ.get']('APP_STORE_STORES_SETTINGS') + "'" %}
{% set APP_STORE_ENCRYPTION_KEY = "'" + salt['environ.get']('APP_STORE_ENCRYPTION_KEY') + "'" %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}

Sync_Apps:
  cmd.run:
    - name: tethys db sync
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

Sync_App_Persistent_Stores:
  cmd.run:
    - name: tethys syncstores all
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

Set_Custom_Settings:
  cmd.run:
    - name: >
        tethys app_settings set app_store sudo_server_pass {{ APP_STORE_SERVER_PASS }} &&
        tethys app_settings set app_store stores_settings {{ APP_STORE_STORES_SETTINGS }} &&
        tethys app_settings set app_store encryption_key {{ APP_STORE_ENCRYPTION_KEY }}
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

Set_Git_Identity:
  cmd.run:
    - name: >
        git config --global user.email "{{ APP_INSTALLER_USER_EMAIL }}" &&
        git config --global user.name "{{ APP_INSTALLER_USER_NAME }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

Flag_Init_Apps_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/init_apps_setup_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"