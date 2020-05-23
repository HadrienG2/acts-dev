####################### CONTAINER-SIDE ACTS BUILD SCRIPT #######################
# This script is meant to run inside of the container. If you are trying to    #
# build the container, you're probably looking for the "build.sh" script.      #
################################################################################

# Force bash to catch more errors
set -euo pipefail
# NOTE: Don't exclude spaces from IFS as spack spec need it

# Go to the build directory and flush remains of previous build
cd /mnt/acts
rm -rf spack-*

# Run a spack build of Acts
#
# FIXME: Set back to unlimited concurrency once I have more than 16 GB of RAM
#
spack dev-build -j2 --until build ${ACTS_SPACK_SPEC}
cd spack-build

# Run the unit tests
spack build-env acts ctest -j8
echo "==============="

# Run the integration tests as well
spack build-env acts -- cmake --build . -- integrationtests
echo "==============="

# Run the benchmarks as well
cd bin
spack build-env acts ./ActsBenchmarkAtlasStepper
echo "---------------"
spack build-env acts ./ActsBenchmarkBoundaryCheck
echo "---------------"
spack build-env acts ./ActsBenchmarkEigenStepper
echo "---------------"
spack build-env acts ./ActsBenchmarkSolenoidField
echo "---------------"
spack build-env acts ./ActsBenchmarkSurfaceIntersection
echo "==============="

# Run the framework examples as well
#
# FIXME: Cannot test ActsExampleMagneticField, ActsExampleMagneticFieldAccess,
#        ActsExampleMaterialMappingDD4hep, ActsExampleMaterialMappingGeneric,
#        ActsExampleReadCsvGeneric, ActsRecTruthTracks, ActsRecVertexReader and
#        ActsSimFatrasTGeo as no input data file is provided and it's unclear
#        how to get one.
#
# FIXME: Cannot auto-test ActsExampleGeometryTGeo, ActsExampleHepMC3 and
#        ActsExamplePropagationTGeo as they do not reliably exit a nonzero
#        status code upon major failure (e.g. input not found).
#
# FIXME: The PayloadDetector-based examples ActsExamplePropagationPayload and
#        ActsSimFatrasPayload crash with a bad_any_cast, see
#        https://github.com/acts-project/acts/issues/164 .
#
# FIXME: The ActsSimGeantinoRecording example must be forced into
#        single-threaded mode with -j1 until
#        https://github.com/acts-project/acts/issues/207 is resolved.
#
DD4HEP_PREFIX=`spack location --install-dir dd4hep`
set +u && source ${DD4HEP_PREFIX}/bin/thisdd4hep.sh && set -u
cd /mnt/acts/Examples
run_example () {
    spack build-env --dirty acts ../spack-build/bin/$* -n 100
}
run_example ActsExampleGeometryAligned
echo "---------------"
run_example ActsExampleGeometryDD4hep
echo "---------------"
run_example ActsExampleGeometryEmpty
echo "---------------"
run_example ActsExampleGeometryGeneric
echo "---------------"
run_example ActsExampleGeometryPayload
echo "---------------"
run_example ActsExampleHelloWorld
echo "---------------"
run_example ActsExampleMaterialValidationDD4hep
echo "---------------"
run_example ActsExampleMaterialValidationGeneric
echo "---------------"
run_example ActsExamplePropagationAligned
echo "---------------"
run_example ActsExamplePropagationDD4hep
echo "---------------"
run_example ActsExamplePropagationEmpty
echo "---------------"
run_example bin/ActsExamplePropagationGeneric
echo "---------------"
run_example ActsGenParticleGun
echo "---------------"
run_example ActsGenPythia8
echo "---------------"
run_example ActsRecVertexFinder
echo "---------------"
run_example ActsRecVertexFitter
echo "---------------"
run_example ActsRecVertexWriter
echo "---------------"
run_example ActsSimFatrasAligned
echo "---------------"
run_example ActsSimFatrasDD4hep
echo "---------------"
run_example ActsSimFatrasGeneric
echo "---------------"
run_example ActsSimGeantinoRecording -j1
echo "==============="

# Try to keep docker image size down by dropping build stages, downloads, etc
#
# Note that you should _not_ run `spack gc` here as that would drop spack
# packages which are necessary for Acts to build, but not to run. Which is not
# what we want, we want a working Acts build environment here !
#
spack clean -a
