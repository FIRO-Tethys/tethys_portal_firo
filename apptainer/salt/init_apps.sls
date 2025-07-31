{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}

{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}

Sync_Apps:
  cmd.run:
    - name: tethys db sync
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"
    
Sync_Tethysdash_Persistent_Stores:
  cmd.run:
    - name: tethys syncstores tethysdash
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

Flag_Init_Apps_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/init_apps_setup_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"