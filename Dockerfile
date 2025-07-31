FROM tethysplatform/tethys-core:dev-py3.12-dj5.0 as base

###############################
# ARGS VARIABLES
###############################

ARG TETHYS_PORTAL_HOST=""
ARG TETHYS_APP_ROOT_URL="/apps/tethysdash/"
ARG TETHYS_LOADER_DELAY="500"
ARG TETHYS_DEBUG_MODE="false"

###############################
# DEFAULT ENVIRONMENT VARIABLES
###############################

ENV TETHYS_DASH_APP_SRC_ROOT=${TETHYS_HOME}/apps/tethysdash
ENV DEV_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/development.env"
ENV PROD_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/production.env"
# ENV NGINX_PORT=8080

####################
# ADD APPLICATIONS #
####################
COPY tethysdash ${TETHYS_HOME}/apps/tethysdash
COPY tethysdash_plugin_cnrfc ${TETHYS_HOME}/apps/tethysdash_plugin_cnrfc
COPY tethysdash_plugin_cw3e ${TETHYS_HOME}/apps/tethysdash_plugin_cw3e
COPY tethysdash_plugin_usace ${TETHYS_HOME}/apps/tethysdash_plugin_usace
COPY requirements.txt .


##############
# SETUP      #
##############

# Install dos2unix to convert windows saved bash files to work in unix
RUN apt-get update && \
    apt-get install dos2unix


# Install NPM with NVM
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=20.12.2
RUN mkdir -p ${NVM_DIR} \
  && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | /bin/bash \
  && . ${NVM_DIR}/nvm.sh \
  && nvm install ${NODE_VERSION} \
  && nvm alias default ${NODE_VERSION} \
  && nvm use default

ENV NODE_VERSION_DIR=${NVM_DIR}/versions/node/v${NODE_VERSION}
ENV NODE_PATH=${NODE_VERSION_DIR}/lib/node_modules
ENV PATH=${NODE_VERSION_DIR}/bin:$PATH
ENV NPM=${NODE_VERSION_DIR}/bin/npm

########################
# INSTALL APPLICATIONS #
########################

ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN pip install --no-cache-dir --quiet -r requirements.txt

RUN mv ${DEV_REACT_CONFIG} ${PROD_REACT_CONFIG} \
  && sed -i "s#TETHYS_DEBUG_MODE.*#TETHYS_DEBUG_MODE = ${TETHYS_DEBUG_MODE}#g" ${PROD_REACT_CONFIG} \
  && sed -i "s#TETHYS_LOADER_DELAY.*#TETHYS_LOADER_DELAY = ${TETHYS_LOADER_DELAY}#g" ${PROD_REACT_CONFIG} \
  && sed -i "s#TETHYS_PORTAL_HOST.*#TETHYS_PORTAL_HOST = ${TETHYS_PORTAL_HOST}#g" ${PROD_REACT_CONFIG} \
  && sed -i "s#TETHYS_APP_ROOT_URL.*#TETHYS_APP_ROOT_URL = ${TETHYS_APP_ROOT_URL}#g" ${PROD_REACT_CONFIG} \
  && cd ${TETHYS_HOME}/apps/tethysdash && npm install && npm run build && tethys install -w -N -q \
  && cd ${TETHYS_HOME}/apps/tethysdash_plugin_cnrfc \
  && pip install --no-cache-dir --quiet . \
  && cd ${TETHYS_HOME}/apps/tethysdash_plugin_cw3e \
  && pip install --no-cache-dir --quiet . \
  && cd ${TETHYS_HOME}/apps/tethysdash_plugin_usace \
  && pip install --no-cache-dir --quiet . 
    

FROM tethysplatform/tethys-core:dev-py3.12-dj5.0 as build

COPY --chown=www:www --from=base ${CONDA_HOME}/envs/${CONDA_ENV_NAME} ${CONDA_HOME}/envs/${CONDA_ENV_NAME}
COPY custom_themes/tethysext-default_theme  ${TETHYS_HOME}/ext/tethysext-default_theme

COPY docker/salt/ /srv/salt/

# Activate tethys conda environment during build
ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN rm -Rf ~/.cache/pip && \
    micromamba clean --all --yes && \
    mkdir -p -m 777 ${TETHYS_PERSIST}/data/tethysdash \
    && cd ${TETHYS_HOME}/ext/tethysext-default_theme \
    && pip install --no-cache-dir --quiet .

EXPOSE 80

WORKDIR ${TETHYS_HOME}
CMD bash run.sh

