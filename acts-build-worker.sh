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
#
# FIXME: Set back to unlimited concurrency once it doesn't OOM anymore
#
spack dev-build -j3 --until build ${ACTS_SPACK_SPEC}
ACTS_BUILD_DIR_NAME=`ls | grep -E "^spack-build[^.]*$"`
ACTS_BUILD_DIR=/mnt/acts/${ACTS_BUILD_DIR_NAME}
cd ${ACTS_BUILD_DIR}

# We're done with Spack ops, so we can perma-source the acts build environment
# since that's what the user of this Acts development image will always want.
source ~/acts-build-env.sh
echo "source ~/acts-build-env.sh" >> ${SETUP_ENV}

# FIXME: Must disable bits of Spack's python environment, as that interacts
#        badly with the system python installation and prevents using gdb.
echo "unset PYTHONHOME" >> ${SETUP_ENV}
echo "unset PYTHONPATH" >> ${SETUP_ENV}

# Run the unit tests
ctest -j8
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
DD4HEP_PREFIX=`spack location --install-dir dd4hep`
DD4HEP_ENV_SCRIPT="${DD4HEP_PREFIX}/bin/thisdd4hep.sh"
DD4HEP_INPUT="--dd4hep-input file:/mnt/acts/Examples/Detectors/DD4hepDetector/compact/OpenDataDetector/OpenDataDetector.xml"
set +u && source ${DD4HEP_ENV_SCRIPT} && set -u
echo "source ${DD4HEP_ENV_SCRIPT}" >> ${SETUP_ENV}
cd /mnt/acts
set +e && ln -s ${ACTS_BUILD_DIR} ${ACTS_SRC_DIR}/build; set -e
./CI/run_examples.sh

# Try to keep docker image size down by dropping build stages, downloads, etc
#
# Note that you should _not_ run `spack gc` here as that would drop spack
# packages which are necessary for Acts to build, but not to run. Which is not
# what we want, we want a working Acts build environment here !
#
spack clean -a
