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

# This is the variant of the Acts package that we are going to build
#
# FIXME: xerces-c cxxstd must be forced to "11" because it's "default" by
#        by default, Geant4 asks for "11", and Spack isn't smart enough to
#        figure out that these two constraints are compatible.
#
# FIXME: dd4hep is disabled because enabling it triggers a link error caused by
#        what looks like a CMake dependency spaghetti. I'm not touching that.
#
ACTS_SPACK_SPEC="acts@master build_type=RelWithDebInfo +benchmarks -dd4hep     \
                             +digitization +examples +fatras +geant4 +hepmc3   \
                             +identification +integration_tests +json +legacy  \
                             +pythia8 +tgeo +unit_tests                        \
                     ^ boost -atomic -chrono cxxstd=17 -date_time -exception   \
                             +filesystem -graph -iostreams -locale -log -math  \
                             +multithreaded +program_options -random -regex    \
                             -serialization +shared -signals -system +test     \
                             -thread -timer -wave                              \
                     ^ ${ROOT_SPACK_SPEC}                                      \
                     ^ xerces-c cxxstd=11"
echo "export ACTS_SPACK_SPEC=\"${ACTS_SPACK_SPEC}\"" >> ${SETUP_ENV}

# Run a spack build of Acts
spack dev-build --until build ${ACTS_SPACK_SPEC}
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
#        ActsExampleMaterialMappingGeneric, ActsExampleReadCsvGeneric,
#        ActsRecTruthTracks, ActsRecVertexReader and ActsSimFatrasTGeo as no
#        input data file is provided and it's unclear how to get one.
#
# FIXME: Cannot auto-test ActsExampleGeometryTGeo, ActsExampleHepMC3 and
#        ActsExamplePropagationTGeo as they do not reliably exit a nonzero
#        status code upon major failure (e.g. input not found).
#
# FIXME: Cannot test ActsExampleGeantinoRecording, ActsExampleGeometryDD4hep,
#        ActsExampleMaterialMappingDD4hep, ActsExampleMaterialValidationDD4hep,
#        ActsExamplePropagationDD4hep and ActsSimFatrasDD4hep as the dd4hep
#        component is currently disabled due to weird build issues (see above).
#
#        Even if I got DD4hep to work again, MaterialMapping would still be
#        problematic due to its lack of clear input file.
#
# FIXME: The PayloadDetector-based examples ActsExamplePropagationPayload and
#        ActsSimFatrasPayload crash with a bad_any_cast, see
#        https://github.com/acts-project/acts/issues/164 .
#
cd ../Examples
spack build-env acts ../bin/ActsExampleGeometryAligned -n 100
echo "---------------"
spack build-env acts ../bin/ActsExampleGeometryEmpty -n 100
echo "---------------"
spack build-env acts ../bin/ActsExampleGeometryGeneric -n 100
echo "---------------"
spack build-env acts ../bin/ActsExampleGeometryPayload -n 100
echo "---------------"
spack build-env acts ../bin/ActsExampleHelloWorld -n 100
echo "---------------"
spack build-env acts ../bin/ActsExampleMaterialValidationGeneric -n 100
echo "---------------"
spack build-env acts ../bin/ActsExamplePropagationAligned -n 100
echo "---------------"
spack build-env acts ../bin/ActsExamplePropagationEmpty -n 100
echo "---------------"
spack build-env acts ../bin/ActsExamplePropagationGeneric -n 100
echo "---------------"
spack build-env acts ../bin/ActsGenParticleGun -n 100
echo "---------------"
spack build-env acts ../bin/ActsGenPythia8 -n 100
echo "---------------"
spack build-env acts ../bin/ActsRecVertexFinder -n 100
echo "---------------"
spack build-env acts ../bin/ActsRecVertexFitter -n 100
echo "---------------"
spack build-env acts ../bin/ActsRecVertexWriter -n 100
echo "---------------"
spack build-env acts ../bin/ActsSimFatrasAligned -n 100
echo "---------------"
spack build-env acts ../bin/ActsSimFatrasGeneric -n 100
echo "==============="
