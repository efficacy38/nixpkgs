{ lib
, buildPythonPackage
, cryptography
, django
, fetchFromGitHub
, mock
, multidict
, pyjwt
, pytestCheckHook
, pythonOlder
, pytz
, requests
}:

buildPythonPackage rec {
  pname = "twilio";
  version = "7.16.4";
  format = "setuptools";

  disabled = pythonOlder "3.6";

  src = fetchFromGitHub {
    owner = "twilio";
    repo = "twilio-python";
    rev = "refs/tags/${version}";
    hash = "sha256-OB7jW+I5oAE2TGPWmuIcXcABY1v1FMjo8UT83Xn4DB8=";
  };

  propagatedBuildInputs = [
    pyjwt
    pytz
    requests
  ];

  nativeCheckInputs = [
    cryptography
    django
    mock
    multidict
    pytestCheckHook
  ];

  disabledTests = [
    # Tests require network access
    "test_set_default_user_agent"
    "test_set_user_agent_extensions"
  ];

  pythonImportsCheck = [
    "twilio"
  ];

  meta = with lib; {
    description = "Twilio API client and TwiML generator";
    homepage = "https://github.com/twilio/twilio-python/";
    changelog = "https://github.com/twilio/twilio-python/blob/${version}/CHANGES.md";
    license = licenses.mit;
    maintainers = with maintainers; [ fab ];
  };
}
