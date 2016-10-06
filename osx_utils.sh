#!/bin/bash
# Use with ``source osx_utils.sh``
set -e

# Get our own location on this filesystem, load common utils
MULTIBUILD_DIR=$(dirname "${BASH_SOURCE[0]}")
source $MULTIBUILD_DIR/common_utils.sh

MACPYTHON_URL=https://www.python.org/ftp/python
MACPYTHON_PY_PREFIX=/Library/Frameworks/Python.framework/Versions
WORKING_SDIR=working

PYPY_URL=https://bitbucket.org/pypy/pypy/downloads

function pyinst_ext_for_version {
    # echo "pkg" or "dmg" depending on the passed Python version
    # Parameters
    #   $py_version (python version in major.minor.extra format)
    #
    # Earlier Python installers are .dmg, later are .pkg.
    local py_version=$1
    check_var $py_version
    py_version=$(fill_pyver $py_version)
    local py_0=${py_version:0:1}
    if [ $py_0 -eq 2 ]; then
        if [ "$(lex_ver $py_version)" -ge "$(lex_ver 2.7.9)" ]; then
            echo "pkg"
        else
            echo "dmg"
        fi
    elif [ $py_0 -ge 3 ]; then
        if [ "$(lex_ver $py_version)" -ge "$(lex_ver 3.4.2)" ]; then
            echo "pkg"
        else
            echo "dmg"
        fi
    fi
}

function install_python {
    # Picks an implementation of Python determined by the current enviroment
    # variables then installs it
    # Sub-function will set $PYTHON_EXE variable to the python executable
    if [ -n "$MB_PYTHON_VERSION" ]; then
        install_macpython $MB_PYTHON_VERSION
    elif [ -n "$PYPY_VERSION" ]; then
        install_mac_pypy $PYPY_VERSION
    elif [ -n "$PYPY3_VERSION" ]; then
        install_mac_pypy3 $PYPY3_VERSION
    else
        echo "config error: expected one of these enviroment variables:"
        echo "    MB_PYTHON_VERSION"
        echo "    PYPY_VERSION"
        echo "    PYPY3_VERSION"
        exit 1
    fi
}

function install_macpython {
    # Installs Python.org Python
    # Parameters:
    #     $version :
    #         major[.minor[.micro]] e.g. "3.4.1", "3.4", or "3"
    # sets $PYTHON_EXE variable to python executable
    local py_version=$(fill_pyver $1)
    local py_stripped=$(strip_ver_suffix $py_version)
    local inst_ext=$(pyinst_ext_for_version $py_version)
    local py_inst=python-$py_version-macosx10.6.$inst_ext
    local inst_path=$DOWNLOADS_SDIR/$py_inst
    mkdir -p $DOWNLOADS_SDIR
    curl $MACPYTHON_URL/$py_stripped/${py_inst} > $inst_path
    if [ "$inst_ext" == "dmg" ]; then
        hdiutil attach $inst_path -mountpoint /Volumes/Python
        inst_path=/Volumes/Python/Python.mpkg
    fi
    sudo installer -pkg $inst_path -target /
    local py_mm=${py_version:0:3}
    PYTHON_EXE=$MACPYTHON_PY_PREFIX/$py_mm/bin/python$py_mm
}


function install_mac_pypy {
    # Installs pypy.org PyPy
    # Parameter $version
    # Version given in major or major.minor or major.minor.micro e.g
    # "3" or "3.4" or "3.4.1".
    # sets $PYTHON_EXE variable to python executable
    local py_version=$(fill_pypy_ver $1)
    local py_build=$(get_pypy_build_prefix $py_version)$py_version-osx64
    local py_zip=$py_build.tar.bz2
    local zip_path=$DOWNLOADS_SDIR/$py_zip
    mkdir -p $DOWNLOADS_SDIR
    wget -nv $PYPY_URL/${py_zip} -P $DOWNLOADS_SDIR
    untar $zip_path
    PYTHON_EXE=$(realpath $py_build/bin/pypy)
}

function install_mac_pypy3 {
    # Installs pypy.org PyPy3
    # Parameter $version
    # Version given in major or major.minor or major.minor.micro e.g
    # "3" or "3.4" or "3.4.1".
    # sets $PYTHON_EXE variable to python executable
    local py_version=$(fill_pypy3_ver $1)
    local py_build=$(get_pypy3_build_prefix $py_version)$py_version-osx64
    local py_zip=$py_build.tar.bz2
    local zip_path=$DOWNLOADS_SDIR/$py_zip
    mkdir -p $DOWNLOADS_SDIR
    wget -nv $PYPY_URL/${py_zip} -P $DOWNLOADS_SDIR
    untar $zip_path
    PYTHON_EXE=$(realpath $py_build/bin/pypy3)
}

function get_macpython_environment {
    # Set up MacPython environment
    # Parameters:
    #     $version :
    #         major.minor.micro e.g. "3.4.1"
    #     $venv_dir : {directory_name|not defined}
    #         If defined - make virtualenv in this directory, set python / pip
    #         commands accordingly
    #
    # Installs Python
    # Sets $PYTHON_EXE to path to Python executable
    # Sets $PIP_CMD to full command for pip (including sudo if necessary)
    # If $venv_dir defined, Sets $VIRTUALENV_CMD to virtualenv executable
    # Puts directory of $PYTHON_EXE on $PATH
    export MB_PYTHON_VERSION=$1
    get_python_environment $2
}

function repair_wheelhouse {
    local wheelhouse=$1
    pip install delocate
    delocate-listdeps $wheelhouse/*.whl # lists library dependencies
    delocate-wheel $wheelhouse/*.whl # copies library dependencies into wheel
    # Add platform tags to label wheels as compatible with OSX 10.9 and
    # 10.10.  The wheels will be built against Python.org Python, and so will
    # in fact be compatible with OSX >= 10.6.  pip < 6.0 doesn't realize
    # this, so, in case users have older pip, add platform tags to specify
    # compatibility with later OSX.  Not necessary for OSX released well
    # after pip 6.0.  See:
    # https://github.com/MacPython/wiki/wiki/Spinning-wheels#question-will-pip-give-me-a-broken-wheel
    delocate-addplat --rm-orig -x 10_9 -x 10_10 $wheelhouse/*.whl
}
