ARG PYTHON_VERSION=3.12

########################################################################################
# Dev image is used for development and cicd.
########################################################################################

FROM python:${PYTHON_VERSION} as dev

RUN apt-get update && apt-get install -y --no-install-recommends \
#   pipx: To install Python applications.
    pipx \
#   sudo: To add sudo support to non-root user.
    sudo \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Config pipx
ENV PIPX_HOME=/usr/local/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
ENV PIPX_DEFAULT_PYTHON=/usr/local/bin/python

# Install pdm
RUN pipx install pdm

# Install pre-commit
RUN pipx install pre-commit

# Create a non-root user with sudo permission
ARG USERNAME=ss-python
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --create-home --uid $USER_UID --gid $USER_GID $USERNAME -s /bin/bash \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set permission for related folders
RUN chown -R $USER_UID:$USER_GID $PIPX_HOME $PIPX_BIN_DIR

########################################################################################
# Build image is an intermediate image used for building the project.
########################################################################################

FROM dev as build

# Copy necessary files for build.
COPY pyproject.toml pdm.lock README.md /workspace/
COPY src/ /workspace/src

# Install dependencies and project into the local packages directory.
WORKDIR /workspace
ARG PDM_BUILD_SCM_VERSION=0.0.0
RUN mkdir __pypackages__ && PDM_BUILD_SCM_VERSION=${PDM_BUILD_SCM_VERSION} pdm sync --prod --no-editable

########################################################################################
# Prod image is used for deployment and distribution.
########################################################################################

FROM python:${PYTHON_VERSION}-slim as prod

# NOTE: python docker image has env `PYTHON_VERSION` but with patch version.
# ARG is used here for temporary override without changing the original env.
ARG PYTHON_VERSION=3.12

# Retrieve packages from build stage.
ENV PYTHONPATH=/workspace/pkgs
COPY --from=build /workspace/__pypackages__/${PYTHON_VERSION}/lib /workspace/pkgs

# Retrieve executables from build stage.
COPY --from=build /workspace/__pypackages__/${PYTHON_VERSION}/bin/* /usr/local/bin/

# Set command to run the cli by default.
ENTRYPOINT ["ss-python-cli"]
