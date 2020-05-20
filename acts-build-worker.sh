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
# FIXME: Set back to unlimited concurrency once it doesn't OOM anymore
#
spack install --only dependencies ${ACTS_SPACK_SPEC}
# NOTE: This is where acts-eagen-deps stopped
# TODO: Record /usr/bin/time output
/usr/bin/time -v spack dev-build -j 1 --until build ${ACTS_SPACK_SPEC}
cd spack-build

# Run the unit tests
# NOTE: Not reporting ctest timings as they are too small
spack build-env acts ctest -j8
echo "==============="

# FIXME: Cross-check the current crop of integration tests and adapt
# Run the integration tests as well
# NOTE: Can't use `spack build-env acts -- cmake --build . -- integrationtests`
#       Must manually run them one by one to get fine-grained timings
# TODO: Record /usr/bin/time output
cd bin
for i in {1..3}; do
    # NOTE: Not reporting ATLSeeding timings as they are too small
    # GENERAL NOTE: Use spack build-env bash in interactive runs!
    /usr/bin/time -v spack build-env acts ./ActsIntegrationTestInterpolatedSolenoidBField
    echo "---------------"
    /usr/bin/time -v spack build-env acts ./ActsIntegrationTestPropagation
    echo "---------------"
    /usr/bin/time -v spack build-env acts ./ActsIntegrationTestBVHNavigation
    echo "---------------"
    /usr/bin/time -v spack build-env acts ./ActsIntegrationTestFatrasSimulation
    echo "==============="
done

# Run the benchmarks as well
# TODO: Record benchmark harness output
cd bin
spack build-env acts ./ActsBenchmarkAnnulusBoundsBenchmark
echo "---------------"
spack build-env acts ./ActsBenchmarkAtlasStepper
echo "---------------"
spack build-env acts ./ActsBenchmarkBoundaryCheck
echo "---------------"
spack build-env acts ./ActsBenchmarkEigenStepper
echo "---------------"
spack build-env acts ./ActsBenchmarkRayFrustumBenchmark
echo "---------------"
spack build-env acts ./ActsBenchmarkSolenoidField
echo "---------------"
spack build-env acts ./ActsBenchmarkSurfaceIntersection
echo "==============="

# Run the framework examples as well
#
# FIXME: Cannot test ActsExampleMagneticField, ActsExampleGeantinoRecordingGdml,
#        ActsExampleMagneticFieldAcess, ActsExampleMaterialMappingDD4hep,
#        ActsExampleMaterialMappingGeneric, ActsExampleReadCsvGeneric,
#        ActsExampleCKFTracks, ActsExampleTruthTracks and
#        ActsExampleVertexReader as no input data file is provided and it's
#        unclear how to get one.
#
# FIXME: Cannot auto-test ActsExampleAdaptiveMultiVertexFinder,
#        ActsExampleFatrasAligned, ActsExampleFatrasDD4hep,
#        ActsExampleFatrasGeneric, ActsExampleFatrasTGeo,
#        ActsExampleGeometryTGeo, ActsExampleHepMC3, ActsExamplePropagationTGeo
#        and ActsExampleVertexFitter as they do not reliably exit with a nonzero
#        status code upon major failure (e.g. input not found, propagation
#        failed...).
#
# FIXME: The PayloadDetector-based examples ActsExamplePropagationPayload and
#        ActsExampleFatrasPayload crash with a bad_any_cast, see
#        https://github.com/acts-project/acts/issues/164 .
#
# FIXME: The ActsSimGeantinoRecordingDD4hep example must be forced into
#        single-threaded, see https://github.com/acts-project/acts/issues/207 .
#
DD4HEP_PREFIX=`spack location --install-dir dd4hep`
set +u && source ${DD4HEP_PREFIX}/bin/thisdd4hep.sh && set -u
cd /mnt/acts/Examples
run_example () {
    spack build-env --dirty acts                                                       \
        /usr/bin/time -v                                                       \
            ../spack-build/bin/$* -n 100 -j1
}
for i in {1..3}; do
    # NOTE: Not running examples GeometryAligned, GeometryEmpty,
    #       GeometryGeneric, GeometryPayload, HelloWorld and ParticleGun,
    #       because they are too fast for reproducible timings
    # TODO: Must record individual job timings
    run_example ActsExampleGeantinoRecording
    echo "---------------"
    run_example ActsExampleGeometryDD4hep
    echo "---------------"
    run_example ActsExampleIterativeVertexFinder
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
    run_example ActsExamplePropagationGeneric
    echo "---------------"
    run_example ActsExamplePythia8
    echo "---------------"
    run_example ActsExampleVertexWriter
    echo "==============="
done

# Try to keep docker image size down by dropping build stages, downloads, etc
#
# Note that you should _not_ run `spack gc` here as that would drop spack
# packages which are necessary for Acts to build, but not to run. Which is not
# what we want, we want a working Acts build environment here !
#
spack clean -a
