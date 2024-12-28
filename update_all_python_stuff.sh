#!/bin/bash

echo "Launching next command in 3 seconds..." && sleep 3
echo "Please enter password when prompted to do so"
sudo -H pip install --upgrade pip argon2-cffi ipywidgets \
    notebook appdirs attr attrs brotli certifi charset_normalizer \
    contourpy cycler debugpy fonttools fs glances injector joblib \
    kiwisolver lz4 matplotlib meson mpmath ninja numpy==1.24.4 \
    packaging peewee pillow pip-autoremove pip-review psutil \
    py3nvml pygobject pyparsing python_dateutil python_xlib \
    pyxdg reactivex requests rx scikit_learn setuptools_scm \
    six sympy threadpoolctl tomli typing_extensions ufoLib2 \
    ujson undervolt unicodedata2 Xlib xmltodict \
    python-xlib==0.29 beniget gast pyopengl pyqtgraph \
    pythran scipy pylint annotated_types anyio argon2 \
    args arrow astroid async_lru atom azure_core \
    azure_storage_blob b2sdk babel boto3 botocore boxsdk \
    cachetools chardet clint comm debtcollector dill \
    dropbox ecdsa exceptiongroup fasteners fastjsonschema \
    fqdn gdata google google_api_core google_api_python_client \
    googleapis_common_protos google_auth google_auth_httplib2 \
    google_auth_oauthlib h11 httpcore httpx humanize \
    iso8601 isodate isoduration isort jmespath jottalib \
    json5 jsonpointer jsonschema jsonschema_specifications \
    jupyter_client jupyter_core jupyter_events jupyterlab \
    jupyterlab_server jupyterlab_widgets jupyter_lsp \
    jupyter jupyter_server jupyter_server_terminals logfury \
    mccabe mediafire megatools mistune mock msgpack \
    msgpack_python nbconvert nbformat netaddr notebook_shim \
    oauth2client orjson overrides platformdirs playhouse \
    prometheus_client protobuf proto_plus pyasn1 pyasn1_modules \
    pydrive2 pyopenssl python_gettext python_json_logger \
    python_swiftclient pyzmq referencing requests_oauthlib \
    requests_toolbelt rfc3339_validator rfc3986 rfc3986_validator \
    rpds rpds_py rsa s3transfer scripts send2trash simplejson \
    sniffio stone terminado tinycss2 tlslite tlslite_ng tomlkit \
    tornado traitlets types_python_dateutil uri_template \
    uritemplate urllib3 webcolors websocket websocket_client \
    widgetsnbextension wrapt xlib zmq
echo "Launching next command in 3 seconds..." && sleep 3
sudo -H pip install -r \
    "/home/$USER/Documents/all_git/gwe/requirements.txt"
echo "Launching next command in 3 seconds..." && sleep 3
# Disabling because of required pip install syntax
#shellcheck disable=SC2102
pip install --user --upgrade pip antiword argcomplete \
    contourpy cycler docutils fonttools geographiclib \
    geopy glances joblib kiwisolver lxml markups matplotlib \
    meson ninja numpy==1.24.4 packaging pillow \
    pip-autoremove pip-review pipx podman-compose psutil \
    pycryptodomex pyenchant pyparsing pyqt6 pyqt6-qt6 pyqt6-sip \
    pyqt6-webengine pyqt6-webengine-qt6 python-dateutil \
    python-dotenv python-markdown-math retext scikit-learn \
    six setuptools threadpoolctl ujson urllib3 userpath \
    websockets virtualenv yt-dlp numba cupy-cuda12x pandas \
    nodejs seaborn[stats] wand imblearn mlxtend
echo "Launching next command in 3 seconds..." && sleep 3
pipx upgrade-all
echo "Launching next command in 3 seconds..." && sleep 3
# Disabling shellcheck justification - allow script to be
#     more adaptable across platforms
#shellcheck disable=SC1090
source "/home/$USER/default_cuda_pytorch/bin/activate"
echo "Launching next command in 3 seconds..." && sleep 3
pip install --upgrade torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu124
# Disabling because of required pip install syntax
#shellcheck disable=SC2102
pip install --upgrade pip pip-autoremove pip-review \
    setuptools wheel ipykernel packaging matplotlib \
    cupy-cuda12x numba transformers ipywidgets jupyterlab_widgets \
    pandas openpyxl sentence-transformers flask langchain \
    pylint python-dotenv
echo "Launching next command in 3 seconds..." && sleep 3
deactivate
echo "Launching next command in 3 seconds..." && sleep 3
# Disabling shellcheck justification - allow script to be
#     more adaptable across platforms
#shellcheck disable=SC1090
source "/home/$USER/intel_dpnp/bin/activate"
pip install --upgrade dpnp --index-url \
    https://pypi.anaconda.org/intel/simple
pip install --upgrade pip pip-autoremove pip-review \
    setuptools wheel
echo "Launching next command in 3 seconds..." && sleep 3
deactivate

