{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set STATIC_ROOT = salt['environ.get']('STATIC_ROOT') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}

Move_Custom_Theme_Files_to_Static_Root:
  cmd.run:
    - name: mv {{ TETHYS_HOME }}/custom_theme {{ STATIC_ROOT }}
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/custom_theme_setup_complete" ];"

Move_Custom_Home_Page_to_Tethys_Portal:
  cmd.run:
    - name: cp {{ STATIC_ROOT }}/custom_theme/templates/home.html {{ TETHYS_HOME }}/tethys/tethys_portal/templates/tethys_portal/
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/custom_theme_setup_complete" ];"

Apply_Custom_Theme:
  cmd.run:
    - name: >
        tethys site
        --site-title "FIRO Tethys Portal"
        --brand-text "FIRO Tethys Portal"
        --apps-library-title "Tools"
        --primary-color "#1e6b8b"
        --secondary-color "#fd9a07"
        --background-color "#ffffff"
        --copyright "Copyright © 2024 Aquaveo"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/custom_theme_setup_complete" ];"

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