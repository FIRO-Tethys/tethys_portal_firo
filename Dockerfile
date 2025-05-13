FROM tethysplatform/tethys-core:dev-py3.12-dj5.0

#############
# ADD FILES #
#############
COPY tethysapp-tethys_app_store ${TETHYS_HOME}/apps/tethysapp-tethys_app_store
COPY tethysdash ${TETHYS_HOME}/apps/tethysdash
COPY tethysdash_plugin_cnrfc ${TETHYS_HOME}/apps/tethysdash_plugin_cnrfc
COPY tethysdash_plugin_cw3e ${TETHYS_HOME}/apps/tethysdash_plugin_cw3e
COPY tethysdash_plugin_usace ${TETHYS_HOME}/apps/tethysdash_plugin_usace

###################
# ADD THEME FILES #
###################
COPY images/ /tmp/custom_theme/images/
COPY templates/ /tmp/custom_theme/templates/

###########
# INSTALL #
###########
# Activate tethys conda environment during build
ARG MAMBA_DOCKERFILE_ACTIVATE=1

# Replace static configs with persistent ones
# COPY config/tethys/asgi_supervisord.conf ${TETHYS_HOME}/configs/asgi_supervisord.conf
# COPY config/tethys/supervisord.conf /etc/supervisor/supervisord.conf
COPY requirements.txt .

# Install dos2unix to convert windows saved bash files to work in unix
RUN apt-get update && \
    apt-get install dos2unix

# Install package requirements
RUN pip install --no-cache-dir --quiet -r requirements.txt

# Tethys App Store
# RUN cd ${TETHYS_HOME}/apps/tethysapp-tethys_app_store && \
#     dos2unix tethysapp/app_store/scripts/mamba_install.sh && \
#     dos2unix tethysapp/app_store/scripts/mamba_uninstall.sh && \
#     dos2unix tethysapp/app_store/scripts/mamba_update.sh && \
#     tethys install -N

# TethysDash
RUN cd ${TETHYS_HOME}/apps/tethysdash && \
    tethys install -N
RUN cd ${TETHYS_HOME}/apps/tethysdash_plugin_cnrfc && \
    pip install .
RUN cd ${TETHYS_HOME}/apps/tethysdash_plugin_cw3e && \
    pip install .
RUN cd ${TETHYS_HOME}/apps/tethysdash_plugin_usace && \
    pip install .
RUN mkdir -p -m 777 ${TETHYS_PERSIST}/data/tethysdash

##################
# ADD SALT FILES #
##################
COPY docker/salt/ /srv/salt/

#########
# PORTS #
#########
EXPOSE 80

#######
# RUN #
#######
WORKDIR ${TETHYS_HOME}
CMD bash run.sh