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
cd spack-build

# We're done with Spack ops, so we can perma-source the acts build environment
# since that's what the user of this Acts development image will always want.
source ~/acts-build-env.sh
echo "source ~/acts-build-env.sh" >> ${SETUP_ENV}

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

# Run the framework examples as well
#
# FIXME: Cannot test ActsExampleGeantinoRecordingGdml, ActsExampleMagneticField,
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
# FIXME: The ActsExampleGeantinoRecordingDD4hep example must be forced into
#        single-threaded, see https://github.com/acts-project/acts/issues/207 .
#
# FIXME: ActsExamplePropagationEmpty fails for unknown reasons, reaching an
#        infinite step count.
#
DD4HEP_PREFIX=`spack location --install-dir dd4hep`
set +u && source ${DD4HEP_PREFIX}/bin/thisdd4hep.sh && set -u
cd /mnt/acts/Examples
run_example () { /mnt/acts/spack-build/bin/$* -n 100; }
run_example ActsExampleGeantinoRecordingDD4hep -j1
echo "---------------"
run_example ActsExampleGenParticleGun
echo "---------------"
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
run_example ActsExamplePropagationGeneric
echo "---------------"
run_example ActsExamplePythia8
echo "---------------"
run_example ActsExampleVertexWriter
echo "==============="

# Try to keep docker image size down by dropping build stages, downloads, etc
#
# Note that you should _not_ run `spack gc` here as that would drop spack
# packages which are necessary for Acts to build, but not to run. Which is not
# what we want, we want a working Acts build environment here !
#
spack clean -a
