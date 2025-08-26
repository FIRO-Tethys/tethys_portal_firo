{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set PREFIX_URL = salt['environ.get']('PREFIX_URL') %}

Nginx_patch:
  cmd.run:
    - name: >
        FILE="{{ TETHYS_PERSIST }}/tethys_nginx.conf";
        PREFIX_URL="{{ PREFIX_URL }}";
        sed -i \
          -e "s|^\([[:space:]]*location \)/workspaces\([[:space:]]*{\)|\1${PREFIX_URL%/}/workspaces\2|" \
          -e "s|^\([[:space:]]*location \)/static\([[:space:]]*{\)|\1${PREFIX_URL%/}/static\2|" \
          -e "s|^\([[:space:]]*location \)/media\([[:space:]]*{\)|\1${PREFIX_URL%/}/media\2|" \
          "$FILE"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f '{{ TETHYS_PERSIST }}/post_nginx_patch_complete' ]"

Flag_Post_Nginx_patch_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/post_nginx_patch_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/post_nginx_patch_complete" ];"