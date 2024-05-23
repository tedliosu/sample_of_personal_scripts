#!/bin/bash

echo "Launching next command in 3 seconds..." && sleep 3
echo "Please enter password when prompted to do so"
sudo -H pip install --upgrade pip argon2-cffi \
    ipywidgets notebook appdirs attr attrs \
    brotli certifi charset_normalizer contourpy \
    cycler debugpy duplicity fonttools fs glances \
    injector joblib kiwisolver lz4 matplotlib meson \
    mpmath ninja numpy==1.24.4 packaging peewee \
    pillow pip-autoremove pip-review psutil py3nvml \
    pygobject pyparsing python_dateutil python_xlib \
    pyxdg reactivex requests rx scikit_learn \
    setuptools_scm six sympy threadpoolctl tomli \
    typing_extensions ufoLib2 ujson undervolt \
    unicodedata2 Xlib xmltodict python-xlib==0.29 \
    beniget gast pyopengl pyqtgraph pythran scipy
echo "Launching next command in 3 seconds..." && sleep 3
sudo -H pip install -r \
    "/home/$USER/Documents/all_git/gwe/requirements.txt"
echo "Launching next command in 3 seconds..." && sleep 3
pip install --user --upgrade pip antiword argcomplete \
    contourpy cycler docutils fonttools geographiclib \
    geopy glances joblib kiwisolver lxml markups matplotlib \
    meson mutagen ninja numpy==1.24.4 packaging pillow \
    pip-autoremove pip-review pipx podman-compose psutil \
    pycryptodomex pyenchant pyparsing pyqt6 pyqt6-qt6 pyqt6-sip \
    pyqt6-webengine pyqt6-webengine-qt6 python-dateutil \
    python-dotenv python-markdown-math retext scikit-learn \
    six setuptools threadpoolctl ujson urllib3 userpath \
    websockets yt-dlp virtualenv
echo "Launching next command in 3 seconds..." && sleep 3
pipx upgrade-all
echo "Launching next command in 3 seconds..." && sleep 3
# Disabling shellcheck justification - allow script to be
#     more adaptable across platforms
#shellcheck disable=SC1090
source "/home/$USER/default_cuda_pytorch/bin/activate"
echo "Launching next command in 3 seconds..." && sleep 3
pip install --upgrade torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu118
pip install --upgrade pip pip-autoremove pip-review \
    setuptools wheel ipykernel packaging matplotlib
echo "Launching next command in 3 seconds..." && sleep 3
deactivate

