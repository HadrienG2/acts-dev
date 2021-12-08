####################### CONTAINER-SIDE ACTS BUILD SCRIPT #######################
# This script is meant to run inside of the container. If you are trying to    #
# build the container, you're probably looking for the "build.sh" script.      #
################################################################################

# Force bash to catch more errors
set -euo pipefail
# NOTE: Don't exclude spaces from IFS as spack spec need it

# Flush remains of any previous build
rm -rf spack-*

# Run a spack build of Acts
spack dev-build --until build ${ACTS_SPACK_SPEC}
ACTS_BUILD_DIR_NAME=`ls | grep -E "^spack-build[^.]*$"`
ACTS_SRC_DIR=/mnt/acts
ACTS_BUILD_DIR=${ACTS_SRC_DIR}/${ACTS_BUILD_DIR_NAME}
cd ${ACTS_BUILD_DIR}

# Set up the dd4hep environment
DD4HEP_PREFIX=`spack location --install-dir dd4hep`
DD4HEP_ENV_SCRIPT="${DD4HEP_PREFIX}/bin/thisdd4hep.sh"
set +u && source ${DD4HEP_ENV_SCRIPT} && set -u
echo "source ${DD4HEP_ENV_SCRIPT}" >> ${SETUP_ENV}

# Try to keep docker image size down by dropping build stages, downloads, etc
#
# Note that you should _not_ run `spack gc` here as that would drop spack
# packages which are necessary for Acts to build, but not to run. Which is not
# what we want, we want a working Acts build environment here !
#
spack clean -a

# We're done with Spack ops, so we can perma-source the acts build environment
# since that's what the user of this Acts development image will always want.
source ~/acts-build-env.sh
echo "source ~/acts-build-env.sh" >> ${SETUP_ENV}

# FIXME: Must disable bits of Spack's python environment, as that interacts
#        badly with the system python installation and prevents using gdb.
echo "unset PYTHONHOME" >> ${SETUP_ENV}
echo "unset PYTHONPATH" >> ${SETUP_ENV}

# Run the unit tests
ctest -j$(nproc)
echo "==============="

# Run the integration tests as well
cmake --build . -- integrationtests
echo "==============="

# Run the benchmarks as well
cd bin
./ActsBenchmarkAnnulusBoundsBenchmark
echo "---------------"
./ActsBenchmarkAtlasStepper
echo "---------------"
./ActsBenchmarkBoundaryCheck
echo "---------------"
./ActsBenchmarkEigenStepper
echo "---------------"
./ActsBenchmarkRayFrustumBenchmark
echo "---------------"
./ActsBenchmarkSolenoidField
echo "---------------"
./ActsBenchmarkSurfaceIntersection
echo "==============="

# Run the examples
DD4HEP_INPUT="--dd4hep-input file:${ACTS_SRC_DIR}/Examples/Detectors/DD4hepDetector/compact/OpenDataDetector/OpenDataDetector.xml"
cd ${ACTS_SRC_DIR}
rm -f ${ACTS_SRC_DIR}/build
ln -s ${ACTS_BUILD_DIR} ${ACTS_SRC_DIR}/build
./CI/run_examples.sh
