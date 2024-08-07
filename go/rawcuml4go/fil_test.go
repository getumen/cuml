package rawcuml4go_test

import (
	"testing"

	cuml4go "github.com/getumen/cuml-bindings/go"
	"github.com/getumen/cuml-bindings/go/rawcuml4go"
	"github.com/stretchr/testify/require"
)

func TestFIL(t *testing.T) {

	deviceResource, err := rawcuml4go.NewDeviceResource()
	require.NoError(t, err)
	defer deviceResource.Close()

	target, err := rawcuml4go.NewFILModel(
		deviceResource,
		int(cuml4go.XGBoost),
		"../../testdata/xgboost.model",
		int(cuml4go.AlgoAuto),
		true,
		0.0,
		int(cuml4go.Dense),
		0,
		1,
		0)
	require.NoError(t, err)

	nRow := 114
	numClass := 2

	features := csvToFloat32Array(t, "../../testdata/feature.csv")
	expectedScores := csvToFloat32Array(t, "../../testdata/score-xgboost.csv")

	actual, err := target.Predict(features, nRow, true, nil)
	if err != nil {
		t.Fatal(err)
	}

	require.Equal(t, numClass*len(expectedScores), len(actual))

	defer target.Close()
}
