####################### CONTAINER-SIDE ACTS BUILD SCRIPT #######################
# This script is meant to run inside of the container. If you are trying to    #
# build the container, you're probably looking for the "build.sh" script.      #
################################################################################

# Force bash to catch more errors
set -euo pipefail
# NOTE: Don't exclude spaces from IFS as spack spec need it

# Go to the build directory
cd /mnt/acts-core

# This is the variant of the Acts package that we are going to build
ACTS_SPACK_SPEC="acts-core@develop build_type=RelWithDebInfo +benchmarks       \
                                   +dd4hep +digitization +examples +fatras     \
                                   +identification +integration_tests +json    \
                                   +legacy +tests +tgeo                        \
                     ^ boost -atomic -chrono cxxstd=17 -date_time -exception   \
                             -filesystem -graph -iostreams -locale -log -math  \
                             +multithreaded +program_options -random -regex    \
                             -serialization +shared -signals -system +test     \
                             -thread -timer -wave                              \
                     ^ ${ROOT_SPACK_SPEC}"
echo "export ACTS_SPACK_SPEC=\"${ACTS_SPACK_SPEC}\"" >> ${SETUP_ENV}

# Run a spack build of Acts
spack dev-build --until build ${ACTS_SPACK_SPEC}
cd spack-build
spack build-env acts-core

# Run the unit tests
ctest -j8

# Run the integration tests as well
cmake --build . -- integrationtests

# Run the benchmarks as well
cd Tests/Benchmarks
./ActsBenchmarkAtlasStepper
./ActsBenchmarkBoundaryCheck
./ActsBenchmarkEigenStepper
./ActsBenchmarkSolenoidField
./ActsBenchmarkSurfaceIntersection
