#!/bin/bash

# Setting C++11 standard with checks to prevent duplicate entries
if ! grep -q "export CXXFLAGS=\"-std=c++11\"" ~/.bashrc; then
    echo "export CXXFLAGS=\"-std=c++11\"" >> ~/.bashrc
fi
if ! grep -q "export CCFLAGS=\"-std=c++11\"" ~/.bashrc; then
    echo "export CCFLAGS=\"-std=c++11\"" >> ~/.bashrc
fi
source ~/.bashrc

set -e

# Create marker directory
STAGE_DIR="${HOME}/.mimicnet_stages"
mkdir -p "$STAGE_DIR"

if [ -z "$DISPLAY" ]; then
    echo "DISPLAY not set.  Please ssh with -Y"
    exit 1
fi

if [[ -z $1  || ("$1" != "GPU" && "$1" != "CPU") ]]; then
    echo "Must run with GPU or CPU as first argument"
    exit 1
fi

if [[ "$1" == "GPU" && -z "${CUDA_HOME}" ]]; then
    echo "CUDA_HOME path not set"
    exit 1
fi

BASE_DIR=`pwd`
echo "Starting MimicNet setup in ${BASE_DIR}..."

touch ~/.Xauthority

# Check environment variables stage
if [[ -f "${STAGE_DIR}/env_vars_done" ]]; then
    echo "Environment variables already set, skipping this step..."
else
    echo "Setting environment variables..."
    sudo rm -f /etc/profile.d/mimicnet.sh
    echo "export TCL_LIBRARY=/usr/share/tcltk/tcl8.6" | sudo tee -a /etc/profile.d/mimicnet.sh

    echo "" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export MIMICNET_HOME=${BASE_DIR}/MimicNet" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export INET_HOME=${BASE_DIR}/parallel-inet" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export OPT_HOME=${BASE_DIR}/opt" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export PATH=\$PATH:${BASE_DIR}/parallel-inet-omnet/bin" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${BASE_DIR}/parallel-inet-omnet/lib" | sudo tee -a /etc/profile.d/mimicnet.sh

    echo "" | sudo tee -a /etc/profile.d/mimicnet.sh
    # Anaconda goes first!
    echo "export PATH=${BASE_DIR}/opt/anaconda3/bin:\$PATH" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export CMAKE_PREFIX_PATH=\$CMAKE_PREFIX_PATH:${BASE_DIR}/opt/anaconda3" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export PKG_CONFIG_PATH=\$PKG_CONFIG_PATH:${BASE_DIR}/opt/anaconda3/lib/pkgconfig" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${BASE_DIR}/opt/anaconda3/lib" | sudo tee -a /etc/profile.d/mimicnet.sh

    echo "" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export CMAKE_INCLUDE_PATH=\$CMAKE_INCLUDE_PATH:${BASE_DIR}/opt/include" | sudo tee -a /etc/profile.d/mimicnet.sh

    if [ "$1" == "GPU" ]; then
        echo "" | sudo tee -a /etc/profile.d/mimicnet.sh
        echo "export PATH=\$PATH:${CUDA_HOME}/bin" | sudo tee -a /etc/profile.d/mimicnet.sh
        echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${CUDA_HOME}/lib64" | sudo tee -a /etc/profile.d/mimicnet.sh
    fi

    echo "" | sudo tee -a /etc/profile.d/mimicnet.sh
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${BASE_DIR}/opt/lib" | sudo tee -a /etc/profile.d/mimicnet.sh
    source /etc/profile.d/mimicnet.sh
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/env_vars_done"
    echo "Environment variables setup completed"
fi

# Check system prerequisites stage
if [[ -f "${STAGE_DIR}/prereqs_done" ]]; then
    echo "System prerequisites already installed, skipping this step..."
else
    echo "Installing prereqs..."
    sudo apt-get update
    sudo apt-get install -y build-essential gcc g++ bison flex perl \
         libqt5opengl5-dev tcl-dev tk-dev libxml2-dev \
        zlib1g-dev default-jre doxygen graphviz libwebkitgtk-1.0
    sudo apt-get install -y openmpi-bin libopenmpi-dev
    sudo apt-get install -y libpcap-dev
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/prereqs_done"
    echo "System prerequisites installation completed"
fi

# Check MimicNet code stage
if [[ -f "${STAGE_DIR}/mimicnet_code_done" ]]; then
    echo "MimicNet code already downloaded, skipping this step..."
else
    if [[ ! -d "MimicNet" ]]; then
        echo "Getting MimicNet code..."
        GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone https://github.com/eniac/MimicNet.git
    fi
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/mimicnet_code_done"
    echo "MimicNet code download completed"
fi

# Check OMNET++ installation stage
if [[ -f "${STAGE_DIR}/omnet_done" ]]; then
    echo "OMNET++ already installed, skipping this step..."
else
    echo "Installing OMNET++..."
    cp -r ${MIMICNET_HOME}/third_party/parallel-inet-omnet .
    cd parallel-inet-omnet
    mkdir -p bin
    ./configure
    make MODE=release -j
    cd ..
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/omnet_done"
    echo "OMNET++ installation completed"
fi

# Check INET installation stage
if [[ -f "${STAGE_DIR}/inet_done" ]]; then
    echo "INET already installed, skipping this step..."
else
    echo "Installing INET..."
    cp -r ${MIMICNET_HOME}/third_party/parallel-inet .
    cd parallel-inet
    ./compile.sh
    cd ..
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/inet_done"
    echo "INET installation completed"
fi

# Create directory structure
mkdir -p src
mkdir -p opt
mkdir -p tmp

# Check Anaconda installation stage
if [[ -f "${STAGE_DIR}/anaconda_done" ]]; then
    echo "Anaconda already installed, skipping this step..."
else
    echo "Installing anaconda..."
    cd src/
    rm -f Anaconda3-*
    rm -rf ${BASE_DIR}/opt/anaconda3
    wget https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh
    chmod ugo+x Anaconda3-2024.10-1-Linux-x86_64.sh
    ./Anaconda3-2024.10-1-Linux-x86_64.sh -b -p ${BASE_DIR}/opt/anaconda3
    conda update -y -n base -c defaults conda
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/anaconda_done"
    echo "Anaconda installation completed"
fi

# Check PyTorch prerequisites installation stage
if [[ -f "${STAGE_DIR}/pytorch_prereqs_done" ]]; then
    echo "PyTorch prerequisites already installed, skipping this step..."
else
    echo "Installing pytorch prereqs..."
    sudo apt-get install -y cmake libgflags-dev
    conda install -y numpy
    conda install -y pyyaml mkl mkl-include setuptools cmake cffi typing h5py
    conda install -y -c mingfeima mkldnn
    conda install -y -c pytorch magma-cuda92
    conda install -y pyyaml==6.0.1
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/pytorch_prereqs_done"
    echo "PyTorch prerequisites installation completed"
fi

# Check glog installation stage
if [[ -f "${STAGE_DIR}/glog_done" ]]; then
    echo "glog already installed, skipping this step..."
else
    git clone https://github.com/google/glog.git || true
    cd glog
    git checkout v0.4.0
    ./autogen.sh
    ./configure
    make
    sudo make install
    cd ..
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/glog_done"
    echo "glog installation completed"
fi

# Check pybind11 and PyTorch/ATEN installation stage - combined to ensure they succeed or fail together
if [[ -f "${STAGE_DIR}/pytorch_complete_done" ]]; then
    echo "PyBind11 and PyTorch/ATEN already installed, skipping this step..."
else
    echo "Installing pybind11 and PyTorch/ATEN as a combined step..."
    
    # Create a temporary flag to track success
    touch "${STAGE_DIR}/pytorch_install_in_progress"
    
    # Clone PyTorch repository
    git clone --recursive https://github.com/pytorch/pytorch || true
    cd pytorch
    git checkout v2.6.0
    git rm --cached third_party/nervanagpu || true
    git rm --cached third_party/eigen || true
    git submodule update --init --recursive
    
    # Install pybind11
    cd third_party/pybind11
    python setup.py install
    cp -r include ${BASE_DIR}/opt/
    cd ../..
    
    # Install PyTorch/ATEN
    TMPDIR=${BASE_DIR}/tmp python setup.py install
    cd aten/
    mkdir -p build
    cd build
    if [ "$1" == "GPU" ]; then
        cmake .. -DCMAKE_INSTALL_PREFIX=${BASE_DIR}/opt -DUSE_TENSORRT=OFF -DUSE_NVRTC=ON -DCUDA_TOOLKIT_ROOT_DIR=${CUDA_HOME}
    else
        cmake .. -DCMAKE_INSTALL_PREFIX=${BASE_DIR}/opt -DUSE_TENSORRT=OFF -DUSE_NVRTC=ON
    fi
    make -j
    mkdir -p ${BASE_DIR}/opt/lib
    mkdir -p ${BASE_DIR}/opt/include
    cp -r lib/* ${BASE_DIR}/opt/lib/ || true
    cp -r ../src/ATen ${BASE_DIR}/opt/include/ || true
    cd ../../..
    
    # Remove the old individual flags if they exist
    rm -f "${STAGE_DIR}/pybind11_done" "${STAGE_DIR}/pytorch_aten_done"
    
    # Mark this combined stage as completed
    rm -f "${STAGE_DIR}/pytorch_install_in_progress"
    touch "${STAGE_DIR}/pytorch_complete_done"
    echo "PyBind11 and PyTorch/ATEN installation completed as a single unit"
fi

# Check final installation steps
if [[ -f "${STAGE_DIR}/final_install_done" ]]; then
    echo "Final installation steps already completed, skipping this step..."
else
    pip install msgpack hyperopt
    
    # Mark this stage as completed
    touch "${STAGE_DIR}/final_install_done"
    echo "Final installation steps completed"
fi

echo "All installation steps have been completed!"

# Add completion flag at the end of the script
touch "${STAGE_DIR}/setup_complete"
echo "Setup completion flag has been set."
