{ lib
, buildPythonPackage
, fetchPypi
, cython
, pytestCheckHook
, hypothesis
, readme_renderer
}:

buildPythonPackage rec {
  pname = "marisa-trie";
  version = "0.7.8";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-ruPeXyg2B0z9gD8crxb2g5DyYu8JzX3H0Oiu6baHhkM=";
  };

  nativeBuildInputs = [
    cython
  ];

  nativeCheckInputs = [
    pytestCheckHook
    readme_renderer
    hypothesis
  ];

  postPatch = ''
    substituteInPlace setup.py \
      --replace "hypothesis==" "hypothesis>="
  '';

  preBuild = ''
    ./update_cpp.sh
  '';

  disabledTestPaths = [
    # Don't test packaging
    "tests/test_packaging.py"
  ];

  disabledTests = [
    # Pins hypothesis==2.0.0 from 2016/01 which complains about
    # hypothesis.errors.FailedHealthCheck: tests/test_trie.py::[...] uses
    # the 'tmpdir' fixture, which is reset between function calls but not
    # between test cases generated by `@given(...)`.
    "test_saveload"
    "test_mmap"
  ];

  pythonImportsCheck = [
    "marisa_trie"
  ];

  meta = with lib; {
    description = "Static memory-efficient Trie-like structures for Python based on marisa-trie C++ library";
    longDescription = ''
      There are official SWIG-based Python bindings included in C++ library distribution.
      This package provides alternative Cython-based pip-installable Python bindings.
    '';
    homepage =  "https://github.com/kmike/marisa-trie";
    license = licenses.mit;
    maintainers = with maintainers; [ ixxie ];
  };
}
