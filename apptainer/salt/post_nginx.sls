{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set FORCE_SCRIPT_NAME = salt['environ.get']('FORCE_SCRIPT_NAME') %}

Nginx_patch:
  cmd.run:
    - name: >
        FILE="{{ TETHYS_PERSIST }}/tethys_nginx.conf";
        # Strip any trailing slash from FORCE_SCRIPT_NAME so "/site2/" → "/site2"
        PREFIX="$(echo "{{ FORCE_SCRIPT_NAME }}" | sed 's#/*$##')";
        # Only patch if a prefix is defined and the file has not already been updated
        if [ -n "$PREFIX" ] && ! grep -qE "location ${PREFIX}/static" "$FILE"; then
          # Workspaces
          sed -i -E "s#location /workspaces([[:space:]]*\\{)#location ${PREFIX}/workspaces\\1#g" "$FILE";
          # Static
          sed -i -E "s#location /static([[:space:]]*\\{)#location ${PREFIX}/static\\1#g" "$FILE";
          # Media
          sed -i -E "s#location /media([[:space:]]*\\{)#location ${PREFIX}/media\\1#g" "$FILE";
        fi
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f '{{ TETHYS_PERSIST }}/tethys_services_complete' ]"

Flag_Post_Nginx_patch_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/post_nginx_patch_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/post_nginx_patch_complete" ];"