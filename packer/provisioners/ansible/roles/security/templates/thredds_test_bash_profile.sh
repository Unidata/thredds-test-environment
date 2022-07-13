# Setup maven and add to system bin path.
export M2_HOME="{{ install_dir }}/mvn"
export M2="${M2_HOME}/bin"
export MAVEN_OPTS="-Xms256m -Xmx512m"
DEFAULT_PATH=${M2}:${PATH}

# Add native library tools built by ansible to path.
ANSIBLE_BUILT_BIN="{{ install_dir }}/bin"
export DEFAULT_PATH=${DEFAULT_PATH}:${ANSIBLE_BUILT_BIN}

function activate-conda() {
    CONDA_PROFILE="{{ install_dir }}/miniconda3/etc/profile.d/conda.sh"
    if [[ $(which conda | wc -c) -eq 0 ]]
    then
        source ${CONDA_PROFILE}
    fi
}

function update-path() {
    if ! [ -z "${JAVA_HOME}" ]
    then
        # Use java located in bin directory of JAVA_HOME, if set.
        export PATH="${JAVA_HOME}/bin:${DEFAULT_PATH}"
    else
        # Use temurin java 11 by default.
        export PATH="{{ install_dir }}/{{ default_java_vendor }}{{ default_java_version }}/bin:${DEFAULT_PATH}"
    fi
}

# select-java vendor version
# example:
#    select-java zulu 11
#
# vendor: [ temurin || zulu ] (no default)
# version: [ 8 || 11 || 14 ] (no default)
#
function select-java() {
    VALID_VENDORS=("temurin" "zulu")
    # Caller must supply exactly two arguments.
    if [ ! $# -eq 2 ]
    then
        echo "Invalid arguments. Must supply both \"vendor\" and \"version\", in that order."
    else
        VENDOR=$1
        VERSION=$2
        # Validate the choice of vendor.
        if [[ ! " ${VALID_VENDORS[@]} " =~ " ${VENDOR} " ]]
        then
            VALID=$(printf " || %s" "${VALID_VENDORS[@]}")
            VALID=${VALID:4}
            echo "Invalid value \"${VENDOR}\". Vendor must be one of [ ${VALID} ]"
        else
            MAYBE_JAVA_HOME="{{ install_dir }}/${VENDOR}${VERSION}"
            # Ensure the combination of vendor and version is available on the system.
            if [ -d ${MAYBE_JAVA_HOME} ]
            then
                export JAVA_HOME=${MAYBE_JAVA_HOME}
                update-path
                # If we reach this point, consider the function call successful by
                # setting variable SUCCESS (value does not matter)
                SUCCESS="SET"
            else
                echo "Error: Directory ${MAYBE_JAVA_HOME} does not exists."
            fi
        fi
    fi

    # If the variable SUCCESS is not set, there was an error somewhere, so
    # print out a message that describes the status of JAVA_HOME
    if [ -z ${SUCCESS+x} ]
    then
        if ! [ -z "${JAVA_HOME}" ]
        then
            echo "Will continue to use JAVA_HOME=${JAVA_HOME}"
        else
            echo "JAVA_HOME will remain unset."
        fi
    fi
}

# get_pw id
# example:
#    get_pw password_key
#
# Returns the password associated with the password_key as stored in an
# ansible vault encrypted file.
#
# When decrypted, each line of the vault file should be of the form
# key=value. An environment variable, TV, must be defined and point to
# the location of the file encrypted by ansible vault. A second
# environment variable, AVP, should point to a file containing the
# vault password or a script capiable of of producing the password.
function get_pw() {
  # Caller must supply exactly one argument.
  if [ ! $# -eq 1 ]
  then
    echo "Invalid arguments. Must supply a key contained in the vault."
  else
    ansible-vault view --vault-password-file $AVP $TV | grep "^$1" | cut -d"=" -f2-
  fi
}

# Update the path to pickup additions from DEFAULT_PATH variable.
update-path
