from spack.package import *

class Example(MakefilePackage):
    
    homepage = "https://github.com/sa2c/sombrero"
    url = "https://github.com/sa2c/sombrero/archive/refs/tags/1.0.tar.gz"

    version(
        "2021-08-16", sha256="f62aa1934fef6a025449a9e037345043072be6198f92087853c58c67f1342f73"
    )

    depends_on("mpi")
