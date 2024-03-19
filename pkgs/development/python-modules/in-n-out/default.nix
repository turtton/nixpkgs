{ lib
, buildPythonPackage
, cython_3
, fetchPypi
, future
, pytestCheckHook
, pythonAtLeast
, pythonOlder
, hatchling
, hatch-vcs
, toolz
}:

buildPythonPackage rec {
  pname = "in-n-out";
  version = "0.2.0";
  format = "pyproject";

  disabled = pythonOlder "3.8";

  src = fetchPypi {
    pname = "in_n_out";
    inherit version;
    hash = "sha256-hKJb2/DKl2Dd+rgndujNJWddriHKDpVuIKwOcwL8oZ8=";
  };

  nativeBuildInputs = [
    cython_3
    hatchling
    hatch-vcs
  ];

  propagatedBuildInputs = [
    future
  ];

  nativeCheckInputs = [
    pytestCheckHook
    toolz
  ];

  pythonImportsCheck = [
    "in_n_out"
  ];

  disabledTestPaths = lib.optionals (pythonAtLeast "3.11") [
    # Fatal Python error
    "tests/test_injection.py"
    "tests/test_processors.py"
    "tests/test_providers.py"
    "tests/test_store.py"
  ];

  meta = with lib; {
    description = "Module for dependency injection and result processing";
    homepage = "https://github.com/pyapp-kit/in-n-out";
    changelog = "https://github.com/pyapp-kit/in-n-out/blob/v${version}/CHANGELOG.md";
    license = licenses.bsd3;
    maintainers = with maintainers; [ fab ];
  };
}
