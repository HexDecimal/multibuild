#!/bin/bash
# Utilities to modify the Python installation and environment
# This script is sourced by common_utils.sh

GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py
DOWNLOADS_SDIR=downloads

# As of 7 April 2016 - latest Python of this version with binary
# download.
LATEST_2p7=2.7.11
LATEST_2p6=2.6.6
LATEST_3p2=3.2.5
LATEST_3p3=3.3.5
LATEST_3p4=3.4.4
LATEST_3p5=3.5.1

function check_python {
    if [ -z "$PYTHON_EXE" ]; then
        echo "PYTHON_EXE variable not defined"
        exit 1
    fi
}

function check_pip {
    if [ -z "$PIP_CMD" ]; then
        echo "PIP_CMD variable not defined"
        exit 1
    fi
}

function check_var {
    if [ -z "$1" ]; then
        echo "required variable not defined"
        exit 1
    fi
}

function get_py_digit {
    check_python
    $PYTHON_EXE -c "import sys; print(sys.version_info[0])"
}

function get_py_mm {
    check_python
    $PYTHON_EXE -c "import sys; print('{0}.{1}'.format(*sys.version_info[0:2]))"
}

function get_py_mm_nodot {
    check_python
    $PYTHON_EXE -c "import sys; print('{0}{1}'.format(*sys.version_info[0:2]))"
}

function get_py_prefix {
    check_python
    $PYTHON_EXE -c "import sys; print(sys.prefix)"
}

function fill_pyver {
    # Convert major or major.minor format to major.minor.micro
    #
    # Hence:
    # 2 -> 2.7.11  (depending on LATEST_2p7 value)
    # 2.7 -> 2.7.11  (depending on LATEST_2p7 value)
    local ver=$1
    check_var $ver
    if [[ $ver =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # Major.minor.micro format already
        echo $ver
    elif [ $ver == 2 ] || [ $ver == "2.7" ]; then
        echo $LATEST_2p7
    elif [ $ver == "2.6" ]; then
        echo $LATEST_2p6
    elif [ $ver == 3 ] || [ $ver == "3.5" ]; then
        echo $LATEST_3p5
    elif [ $ver == "3.4" ]; then
        echo $LATEST_3p4
    elif [ $ver == "3.3" ]; then
        echo $LATEST_3p3
    elif [ $ver == "3.2" ]; then
        echo $LATEST_3p2
    else
        echo "Can't fill version $ver"
        exit 1
    fi
}

function make_workon_venv {
    # Make a virtualenv in given directory ('venv' default)
    # Set $PYTHON_EXE, $PIP_CMD to virtualenv versions
    # Parameter $venv_dir
    #    directory for virtualenv
    local venv_dir=$1
    if [ -z "$venv_dir" ]; then
        venv_dir="venv"
    fi
    venv_dir=`abspath $venv_dir`
    check_python
    $VIRTUALENV_CMD --python=$PYTHON_EXE $venv_dir
    PYTHON_EXE=$venv_dir/bin/python
    PIP_CMD=$venv_dir/bin/pip
}

function set_py_vars {
    export PATH="`dirname $PYTHON_EXE`:$PATH"
    export PYTHON_EXE PIP_CMD
}

function remove_travis_ve_pip {
    # Remove travis installs of virtualenv and pip
    if [ "$(sudo which virtualenv)" == /usr/local/bin/virtualenv ]; then
        sudo pip uninstall -y virtualenv;
    fi
    if [ "$(sudo which pip)" == /usr/local/bin/pip ]; then
        sudo pip uninstall -y pip;
    fi
}

function install_virtualenv {
    # Generic install of virtualenv
    # Installs virtualenv into python given by $PYTHON_EXE
    # Assumes virtualenv will be installed into same directory as $PYTHON_EXE
    check_pip
    # Travis VMS install virtualenv for system python by default - force
    # install even if installed already
    $PIP_CMD install virtualenv --ignore-installed
    check_python
    VIRTUALENV_CMD="$(dirname $PYTHON_EXE)/virtualenv"
}

function install_pip {
    # Generic install pip
    # Gets needed version from version implied by $PYTHON_EXE
    # Installs pip into python given by $PYTHON_EXE
    # Assumes pip will be installed into same directory as $PYTHON_EXE
    check_python
    mkdir -p $DOWNLOADS_SDIR
    curl $GET_PIP_URL > $DOWNLOADS_SDIR/get-pip.py
    # Travis VMS now install pip for system python by default - force install
    # even if installed already
    sudo $PYTHON_EXE $DOWNLOADS_SDIR/get-pip.py --ignore-installed
    local py_mm=`get_py_mm`
    PIP_CMD="sudo `dirname $PYTHON_EXE`/pip$py_mm"
}

function get_python_environment {
    # Set up MacPython environment
    # Parameters:
    #     $venv_dir : {directory_name|not defined}
    #         If defined - make virtualenv in this directory, set python / pip
    #         commands accordingly
    #
    # Installs Python
    # Sets $PYTHON_EXE to path to Python executable
    # Sets $PIP_CMD to full command for pip (including sudo if necessary)
    # If $venv_dir defined, Sets $VIRTUALENV_CMD to virtualenv executable
    # Puts directory of $PYTHON_EXE on $PATH
    local venv_dir=$1
    remove_travis_ve_pip
    install_python
    install_pip
    if [ -n "$venv_dir" ]; then
        install_virtualenv
        make_workon_venv $venv_dir
    fi
    set_py_vars
}

function install_python {
    # overwritten in other scripts, if necessary
    :
}