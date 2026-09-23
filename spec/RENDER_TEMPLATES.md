# RENDER_TEMPLATES.md — OMEGA-MUSTACHE Rendering Layer

Production specification for deterministic, typed rendering of semantic results from the Quantum Holographic EGG Crystallization pipeline.

---

## Part 1: RenderModel Architecture

### 1.1 Core Types

All types are defined in `internal/render/model.go`. Zero `map[string]interface{}` anywhere. Full type safety.

#### AgentRenderModel

```go
package render

import (
	"time"
	"encoding/json"
)

// AgentRenderModel is the top-level renderable representation of an agent execution.
type AgentRenderModel struct {
	// Metadata
	AgentID       string                  `json:"agent_id"`
	AgentName     string                  `json:"agent_name"`
	StateID       string                  `json:"state_id"`
	Revision      uint64                  `json:"revision"`
	
	// Execution Status
	OmegaStatus   string                  `json:"omega_status"` // "success", "error", "partial", "pending"
	Verified      bool                    `json:"verified"`
	Rejected      bool                    `json:"rejected"`
	RejectionReason string                `json:"rejection_reason,omitempty"`
	
	// Proof & Derivation
	ProofHash     string                  `json:"proof_hash"`
	ProofTree     *ProofTreeRenderModel   `json:"proof_tree"`
	
	// Semantic State
	State         *StateRenderModel       `json:"state"`
	TensorStates  []*TensorRenderModel    `json:"tensor_states"`
	Derivations   []*DerivationRenderModel `json:"derivations"`
	
	// Errors (if any)
	Errors        []*ErrorRenderModel     `json:"errors,omitempty"`
	
	// Constraints Applied
	Constraints   []*ConstraintRenderModel `json:"constraints,omitempty"`
	
	// Metadata
	StartTime     time.Time               `json:"start_time"`
	EndTime       time.Time               `json:"end_time"`
	Duration      string                  `json:"duration"` // e.g., "234ms"
	ExecutionNonce string                 `json:"execution_nonce"`
}

// ProofTreeRenderModel encodes nested proof derivations.
type ProofTreeRenderModel struct {
	NodeID        string                  `json:"node_id"`
	RuleApplied   string                  `json:"rule_applied"`
	Conclusion    string                  `json:"conclusion"`
	Premises      []*ProofTreeRenderModel `json:"premises,omitempty"`
	ProofStatus   string                  `json:"proof_status"` // "discharged", "pending", "failed"
	Hash          string                  `json:"hash"`
}
```

#### StateRenderModel

```go
// StateRenderModel encodes semantic state for rendering.
type StateRenderModel struct {
	// Identification
	StateID       string                  `json:"state_id"`
	StateName     string                  `json:"state_name"`
	StateVersion  uint64                  `json:"state_version"`
	
	// Semantic Content
	SemanticType  string                  `json:"semantic_type"`
	// Options: "state_vector", "density_matrix", "unitary", "correlator", "surface"
	
	// Quantum States
	StateVector   *StateVectorRenderModel `json:"state_vector,omitempty"`
	DensityMatrix *DensityMatrixRenderModel `json:"density_matrix,omitempty"`
	
	// Constraints & Validation
	Constraints   []*ConstraintBinding    `json:"constraints"`
	AllSatisfied  bool                    `json:"all_satisfied"`
	
	// Bindings (variable → value mappings)
	Bindings      []*BindingRenderModel   `json:"bindings"`
	
	// Hashes for integrity
	StateHash     string                  `json:"state_hash"`
	BindingHash   string                  `json:"binding_hash"`
	
	// Metadata
	Immutable     bool                    `json:"immutable"`
	Sealed        bool                    `json:"sealed"`
}

// StateVectorRenderModel renders quantum state vectors.
type StateVectorRenderModel struct {
	Dimension     int                     `json:"dimension"`
	Basis         string                  `json:"basis"` // "computational", "hadamard", etc.
	Amplitudes    []*ComplexAmplitude     `json:"amplitudes"`
	Normalized    bool                    `json:"normalized"`
	NormValue     float64                 `json:"norm_value"`
}

// ComplexAmplitude encodes a single amplitude.
type ComplexAmplitude struct {
	Index    int     `json:"index"`
	BasisState string `json:"basis_state"` // e.g., "|0⟩", "|1⟩", "|+⟩"
	Real     float64 `json:"real"`
	Imag     float64 `json:"imag"`
	Magnitude float64 `json:"magnitude"`
	Phase    float64 `json:"phase"` // radians
}

// DensityMatrixRenderModel renders mixed quantum states.
type DensityMatrixRenderModel struct {
	Dimension     int                     `json:"dimension"`
	Elements      []*DensityMatrixElement `json:"elements"`
	IsPureState   bool                    `json:"is_pure_state"`
	Purity        float64                 `json:"purity"`
	TraceValue    float64                 `json:"trace_value"`
}

// DensityMatrixElement encodes a single matrix element.
type DensityMatrixElement struct {
	Row          int     `json:"row"`
	Col          int     `json:"col"`
	Real         float64 `json:"real"`
	Imag         float64 `json:"imag"`
	Magnitude    float64 `json:"magnitude"`
}

// ConstraintBinding encodes a constraint and its binding in state.
type ConstraintBinding struct {
	ConstraintID  string                  `json:"constraint_id"`
	ConstraintType string                 `json:"constraint_type"`
	BoundValue    string                  `json:"bound_value"`
	Satisfied     bool                    `json:"satisfied"`
	Violation     string                  `json:"violation,omitempty"`
}

// BindingRenderModel encodes a variable binding.
type BindingRenderModel struct {
	Variable      string                  `json:"variable"`
	Value         string                  `json:"value"`
	ValueType     string                  `json:"value_type"`
	SourceRule    string                  `json:"source_rule"`
	Timestamp     time.Time               `json:"timestamp"`
}
```

#### TensorRenderModel

```go
// TensorRenderModel encodes tensor data for rendering.
type TensorRenderModel struct {
	// Identification
	TensorID      string                  `json:"tensor_id"`
	TensorName    string                  `json:"tensor_name"`
	
	// Structure
	Rank          int                     `json:"rank"`
	Shape         []int                   `json:"shape"`
	ElementType   string                  `json:"element_type"`
	// Options: "complex64", "complex128", "float64", "int32"
	
	// Representation
	RepresentationType string              `json:"representation_type"`
	// Options: "dense", "sparse", "factorized"
	
	// Content
	DenseRepresentation *DenseTensorData    `json:"dense_representation,omitempty"`
	SparseRepresentation *SparseTensorData  `json:"sparse_representation,omitempty"`
	FactorizedRepresentation *FactorizedTensorData `json:"factorized_representation,omitempty"`
	
	// Metadata
	TensorHash    string                  `json:"tensor_hash"`
	ComputedFrom  string                  `json:"computed_from"` // derivation ID
	VerifiedAgainst string                `json:"verified_against"` // constraint ID
	
	// Properties
	Norm          float64                 `json:"norm"`
	ConditionNumber float64               `json:"condition_number,omitempty"`
}

// DenseTensorData encodes full dense tensor representation.
type DenseTensorData struct {
	Elements      []string                `json:"elements"` // JSON stringified values
	RowMajor      bool                    `json:"row_major"`
	Strides       []int                   `json:"strides,omitempty"`
}

// SparseTensorData encodes sparse tensor with coordinates.
type SparseTensorData struct {
	NonZeroCount int                     `json:"non_zero_count"`
	Coordinates  []*SparseCoordinate     `json:"coordinates"`
}

// SparseCoordinate encodes one nonzero element.
type SparseCoordinate struct {
	Indices      []int                   `json:"indices"`
	Value        string                  `json:"value"` // JSON stringified
}

// FactorizedTensorData encodes factorized (SVD, Tucker, TT) format.
type FactorizedTensorData struct {
	FactorizationType string              `json:"factorization_type"`
	// "SVD", "Tucker", "TensorTrain"
	CoreTensor   *DenseTensorData        `json:"core_tensor"`
	Factors      []*Factor               `json:"factors"`
}

// Factor encodes one factor matrix in decomposition.
type Factor struct {
	FactorID      string                  `json:"factor_id"`
	Mode          int                     `json:"mode"`
	Rows          int                     `json:"rows"`
	Cols          int                     `json:"cols"`
	Data          []string                `json:"data"`
}
```

#### DerivationRenderModel

```go
// DerivationRenderModel encodes a derivation (proof of theorem).
type DerivationRenderModel struct {
	// Identification
	DerivationID  string                  `json:"derivation_id"`
	DerivationName string                 `json:"derivation_name"`
	
	// Execution
	CurryQuery    string                  `json:"curry_query"`
	QueryTime     time.Time               `json:"query_time"`
	ExecutionTime string                  `json:"execution_time"` // e.g., "123ms"
	
	// Result
	Result        string                  `json:"result"`
	ResultType    string                  `json:"result_type"`
	
	// Proof Tree
	ProofTree     *ProofTreeRenderModel   `json:"proof_tree"`
	DerivationHash string                 `json:"derivation_hash"`
	
	// Status
	ProofStatus   string                  `json:"proof_status"`
	// "discharged", "pending", "failed", "timeout"
	
	// Steps
	Steps         []*DerivationStep       `json:"steps"`
	
	// Dependencies
	DependsOn     []string                `json:"depends_on"` // state/tensor IDs
}

// DerivationStep encodes one step in proof.
type DerivationStep struct {
	StepID        string                  `json:"step_id"`
	RuleID        string                  `json:"rule_id"`
	RuleName      string                  `json:"rule_name"`
	Applied       string                  `json:"applied"` // e.g., "modus_ponens"
	Premises      []*StepReference        `json:"premises"`
	Conclusion    string                  `json:"conclusion"`
	JustificationHash string               `json:"justification_hash"`
}

// StepReference links to another step.
type StepReference struct {
	StepID        string                  `json:"step_id"`
	ConclusionRef string                  `json:"conclusion_ref"`
}
```

#### ErrorRenderModel

```go
// ErrorRenderModel encodes errors for rendering.
type ErrorRenderModel struct {
	// Error Identification
	ErrorCode     string                  `json:"error_code"`
	ErrorMessage  string                  `json:"error_message"`
	ErrorType     string                  `json:"error_type"`
	// "constraint_violation", "normalization_failure", "dag_cycle",
	// "proof_failure", "io_error", "timeout"
	
	// Context
	Stage         string                  `json:"stage"`
	// "normalization", "constraint_check", "proof_discharge", "crystallization"
	
	// Violation Details
	ViolationKind string                  `json:"violation_kind,omitempty"`
	ViolationDescription string            `json:"violation_description,omitempty"`
	
	// Context Information
	FailedEntityID string                  `json:"failed_entity_id,omitempty"`
	FailedEntityType string                `json:"failed_entity_type,omitempty"`
	
	// Suggestion
	Suggestion    string                  `json:"suggestion,omitempty"`
	RemediationSteps []string             `json:"remediation_steps,omitempty"`
	
	// Recovery
	Recoverable   bool                    `json:"recoverable"`
	Recovery      *ErrorRecoveryPath      `json:"recovery,omitempty"`
	
	// Metadata
	Timestamp     time.Time               `json:"timestamp"`
	StackTrace    string                  `json:"stack_trace,omitempty"`
}

// ErrorRecoveryPath encodes a path to recovery.
type ErrorRecoveryPath struct {
	RecoveryAction string                  `json:"recovery_action"`
	RollbackState  string                  `json:"rollback_state,omitempty"`
	RetryPolicy    string                  `json:"retry_policy"`
}

// ConstraintRenderModel encodes constraint definition.
type ConstraintRenderModel struct {
	ConstraintID  string                  `json:"constraint_id"`
	ConstraintName string                 `json:"constraint_name"`
	ConstraintType string                 `json:"constraint_type"`
	Level         string                  `json:"level"` // "FATAL", "HIGH", "WARN"
	Definition    string                  `json:"definition"`
	
	Status        string                  `json:"status"` // "satisfied", "violated", "pending"
	Details       string                  `json:"details,omitempty"`
}
```

---

## Part 2: Model Construction

### 2.1 StateToRenderModel

```go
// StateToRenderModel converts semantic state to renderable form.
// Deterministic: same input always produces identical output.
func StateToRenderModel(semanticState *semantic.State) (*StateRenderModel, error) {
	if semanticState == nil {
		return nil, fmt.Errorf("semantic state is nil")
	}

	// Basic fields
	model := &StateRenderModel{
		StateID:      semanticState.ID,
		StateName:    semanticState.Name,
		StateVersion: semanticState.Version,
		SemanticType: semanticState.Type,
		Immutable:    semanticState.IsImmutable,
		Sealed:       semanticState.IsSealed,
	}

	// Quantum states
	switch semanticState.Type {
	case "state_vector":
		vec, err := buildStateVector(semanticState)
		if err != nil {
			return nil, err
		}
		model.StateVector = vec

	case "density_matrix":
		dm, err := buildDensityMatrix(semanticState)
		if err != nil {
			return nil, err
		}
		model.DensityMatrix = dm
	}

	// Constraints
	model.Constraints = make([]*ConstraintBinding, len(semanticState.Constraints))
	allSatisfied := true
	for i, constraint := range semanticState.Constraints {
		binding := &ConstraintBinding{
			ConstraintID:   constraint.ID,
			ConstraintType: constraint.Type,
			BoundValue:     constraint.BoundValue,
			Satisfied:      constraint.Satisfied,
		}
		if !constraint.Satisfied {
			allSatisfied = false
			binding.Violation = constraint.Violation
		}
		model.Constraints[i] = binding
	}
	model.AllSatisfied = allSatisfied

	// Bindings
	model.Bindings = make([]*BindingRenderModel, len(semanticState.Bindings))
	for i, binding := range semanticState.Bindings {
		model.Bindings[i] = &BindingRenderModel{
			Variable:   binding.Variable,
			Value:      binding.Value,
			ValueType:  binding.ValueType,
			SourceRule: binding.SourceRule,
			Timestamp:  binding.Timestamp,
		}
	}

	// Compute hashes
	stateHash, err := hashState(semanticState)
	if err != nil {
		return nil, err
	}
	model.StateHash = stateHash

	bindingHash, err := hashBindings(semanticState.Bindings)
	if err != nil {
		return nil, err
	}
	model.BindingHash = bindingHash

	return model, nil
}

// buildStateVector converts quantum state vector to renderable form.
func buildStateVector(semanticState *semantic.State) (*StateVenderRenderModel, error) {
	sv := semanticState.Quantum.StateVector
	if sv == nil {
		return nil, fmt.Errorf("state vector is nil")
	}

	renderModel := &StateVectorRenderModel{
		Dimension:  len(sv.Amplitudes),
		Basis:      sv.Basis,
		Normalized: sv.IsNormalized,
		NormValue:  sv.NormalizationValue,
		Amplitudes: make([]*ComplexAmplitude, len(sv.Amplitudes)),
	}

	for i, amp := range sv.Amplitudes {
		magnitude := math.Sqrt(amp.Real*amp.Real + amp.Imag*amp.Imag)
		phase := math.Atan2(amp.Imag, amp.Real)

		renderModel.Amplitudes[i] = &ComplexAmplitude{
			Index:      i,
			BasisState: computeBasisState(i, len(sv.Amplitudes)),
			Real:       amp.Real,
			Imag:       amp.Imag,
			Magnitude:  magnitude,
			Phase:      phase,
		}
	}

	return renderModel, nil
}

// buildDensityMatrix converts mixed state to renderable form.
func buildDensityMatrix(semanticState *semantic.State) (*DensityMatrixRenderModel, error) {
	dm := semanticState.Quantum.DensityMatrix
	if dm == nil {
		return nil, fmt.Errorf("density matrix is nil")
	}

	renderModel := &DensityMatrixRenderModel{
		Dimension:    dm.Dimension,
		IsPureState:  dm.IsPure,
		Purity:       dm.Purity,
		TraceValue:   dm.Trace,
		Elements:     make([]*DensityMatrixElement, 0),
	}

	// Only include non-negligible elements
	const epsilon = 1e-10
	for i := 0; i < dm.Dimension; i++ {
		for j := 0; j < dm.Dimension; j++ {
			real := dm.Matrix[i][j].Real
			imag := dm.Matrix[i][j].Imag
			magnitude := math.Sqrt(real*real + imag*imag)

			if magnitude > epsilon {
				renderModel.Elements = append(renderModel.Elements, &DensityMatrixElement{
					Row:       i,
					Col:       j,
					Real:      real,
					Imag:      imag,
					Magnitude: magnitude,
				})
			}
		}
	}

	return renderModel, nil
}

// computeBasisState returns readable basis label: "|0⟩", "|1⟩", "|+⟩", etc.
func computeBasisState(index int, total int) string {
	// For binary basis
	if total == 2 {
		if index == 0 {
			return "|0⟩"
		}
		return "|1⟩"
	}
	// For general computational basis
	return fmt.Sprintf("|%d⟩", index)
}

// hashState computes deterministic hash of state.
func hashState(s *semantic.State) (string, error) {
	hasher := blake3.New()
	// Hash type, version, immutability
	_, err := hasher.Write([]byte(s.Type))
	if err != nil {
		return "", err
	}
	_, err = hasher.Write([]byte(fmt.Sprintf("%d", s.Version)))
	if err != nil {
		return "", err
	}

	// Hash quantum content
	if s.Quantum != nil && s.Quantum.StateVector != nil {
		for _, amp := range s.Quantum.StateVector.Amplitudes {
			_, err := hasher.Write([]byte(fmt.Sprintf("%f%f", amp.Real, amp.Imag)))
			if err != nil {
				return "", err
			}
		}
	}

	return hex.EncodeToString(hasher.Sum(nil)[:32]), nil
}
```

### 2.2 TensorToRenderModel

```go
// TensorToRenderModel converts tensor data to renderable form.
func TensorToRenderModel(tensor *semantic.Tensor) (*TensorRenderModel, error) {
	if tensor == nil {
		return nil, fmt.Errorf("tensor is nil")
	}

	model := &TensorRenderModel{
		TensorID:       tensor.ID,
		TensorName:     tensor.Name,
		Rank:           tensor.Rank,
		Shape:          tensor.Shape,
		ElementType:    tensor.ElementType,
		RepresentationType: tensor.Representation.Type,
		ComputedFrom:   tensor.DerivationID,
		VerifiedAgainst: tensor.ConstraintID,
		Norm:           tensor.Norm,
		ConditionNumber: tensor.ConditionNumber,
	}

	// Route to appropriate representation builder
	switch tensor.Representation.Type {
	case "dense":
		dense, err := buildDenseRepresentation(tensor.Representation.Data)
		if err != nil {
			return nil, err
		}
		model.DenseRepresentation = dense

	case "sparse":
		sparse, err := buildSparseRepresentation(tensor.Representation.Data)
		if err != nil {
			return nil, err
		}
		model.SparseRepresentation = sparse

	case "factorized":
		factorized, err := buildFactorizedRepresentation(tensor.Representation.Data)
		if err != nil {
			return nil, err
		}
		model.FactorizedRepresentation = factorized

	default:
		return nil, fmt.Errorf("unknown tensor representation: %s", tensor.Representation.Type)
	}

	// Compute hash
	hash, err := hashTensor(tensor)
	if err != nil {
		return nil, err
	}
	model.TensorHash = hash

	return model, nil
}

// buildDenseRepresentation encodes dense tensor as JSON strings.
func buildDenseRepresentation(data interface{}) (*DenseTensorData, error) {
	// Assume data is []float64 or []complex128
	switch v := data.(type) {
	case []float64:
		elements := make([]string, len(v))
		for i, val := range v {
			b, _ := json.Marshal(val)
			elements[i] = string(b)
		}
		return &DenseTensorData{
			Elements:  elements,
			RowMajor:  true,
		}, nil

	case []complex128:
		elements := make([]string, len(v))
		for i, val := range v {
			// JSON encode complex as {real, imag}
			type C struct {
				Real float64 `json:"real"`
				Imag float64 `json:"imag"`
			}
			b, _ := json.Marshal(C{real(val), imag(val)})
			elements[i] = string(b)
		}
		return &DenseTensorData{
			Elements:  elements,
			RowMajor:  true,
		}, nil

	default:
		return nil, fmt.Errorf("unsupported dense data type: %T", data)
	}
}

// buildSparseRepresentation encodes sparse tensor.
func buildSparseRepresentation(data interface{}) (*SparseTensorData, error) {
	// Assume data is []SparseTensorCoord or similar
	type SparseTensorCoord struct {
		Indices []int       `json:"indices"`
		Value   interface{} `json:"value"`
	}

	coords, ok := data.([]SparseTensorCoord)
	if !ok {
		return nil, fmt.Errorf("sparse data is not SparseTensorCoord slice")
	}

	renderCoords := make([]*SparseCoordinate, len(coords))
	for i, coord := range coords {
		b, _ := json.Marshal(coord.Value)
		renderCoords[i] = &SparseCoordinate{
			Indices: coord.Indices,
			Value:   string(b),
		}
	}

	return &SparseTensorData{
		NonZeroCount: len(renderCoords),
		Coordinates:  renderCoords,
	}, nil
}

// buildFactorizedRepresentation encodes decomposed tensor.
func buildFactorizedRepresentation(data interface{}) (*FactorizedTensorData, error) {
	// Assume data contains type, core, and factors
	decomp := data.(map[string]interface{})

	factType, ok := decomp["type"].(string)
	if !ok {
		return nil, fmt.Errorf("decomposition type missing")
	}

	renderFactorized := &FactorizedTensorData{
		FactorizationType: factType,
		Factors:           make([]*Factor, 0),
	}

	// Parse core tensor
	if coreData, ok := decomp["core"].(interface{}); ok {
		core, err := buildDenseRepresentation(coreData)
		if err != nil {
			return nil, err
		}
		renderFactorized.CoreTensor = core
	}

	// Parse factors
	if factorsData, ok := decomp["factors"].([]interface{}); ok {
		for idx, fdata := range factorsData {
			fmap := fdata.(map[string]interface{})
			rows := int(fmap["rows"].(float64))
			cols := int(fmap["cols"].(float64))

			data := fmap["data"].([]interface{})
			dataStrs := make([]string, len(data))
			for j, d := range data {
				b, _ := json.Marshal(d)
				dataStrs[j] = string(b)
			}

			renderFactorized.Factors = append(renderFactorized.Factors, &Factor{
				FactorID: fmt.Sprintf("factor_%d", idx),
				Mode:     idx,
				Rows:     rows,
				Cols:     cols,
				Data:     dataStrs,
			})
		}
	}

	return renderFactorized, nil
}

// hashTensor computes deterministic tensor hash.
func hashTensor(t *semantic.Tensor) (string, error) {
	hasher := blake3.New()
	_, err := hasher.Write([]byte(t.ID))
	if err != nil {
		return "", err
	}
	for _, s := range t.Shape {
		_, err := hasher.Write([]byte(fmt.Sprintf("%d", s)))
		if err != nil {
			return "", err
		}
	}
	_, err = hasher.Write([]byte(t.Representation.Type))
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(hasher.Sum(nil)[:32]), nil
}
```

### 2.3 DerivationToRenderModel

```go
// DerivationToRenderModel converts proof derivation to renderable form.
func DerivationToRenderModel(derivation *semantic.Derivation) (*DerivationRenderModel, error) {
	if derivation == nil {
		return nil, fmt.Errorf("derivation is nil")
	}

	model := &DerivationRenderModel{
		DerivationID:   derivation.ID,
		DerivationName: derivation.Name,
		CurryQuery:     derivation.Query,
		QueryTime:      derivation.QueryTime,
		ExecutionTime:  formatDuration(derivation.ExecutionDuration),
		Result:         derivation.Result,
		ResultType:     derivation.ResultType,
		ProofStatus:    derivation.ProofStatus,
	}

	// Build proof tree recursively
	proofTree, err := buildProofTree(derivation.ProofTree)
	if err != nil {
		return nil, err
	}
	model.ProofTree = proofTree

	// Convert steps
	model.Steps = make([]*DerivationStep, len(derivation.Steps))
	for i, step := range derivation.Steps {
		premises := make([]*StepReference, len(step.Premises))
		for j, prem := range step.Premises {
			premises[j] = &StepReference{
				StepID:        prem.StepID,
				ConclusionRef: prem.Conclusion,
			}
		}

		model.Steps[i] = &DerivationStep{
			StepID:              step.ID,
			RuleID:              step.RuleID,
			RuleName:            step.RuleName,
			Applied:             step.AppliedRule,
			Premises:            premises,
			Conclusion:          step.Conclusion,
			JustificationHash:   step.JustificationHash,
		}
	}

	// Dependencies
	model.DependsOn = derivation.DependsOn

	// Compute derivation hash
	hash, err := hashDerivation(derivation)
	if err != nil {
		return nil, err
	}
	model.DerivationHash = hash

	return model, nil
}

// buildProofTree recursively converts proof tree.
func buildProofTree(tree *semantic.ProofNode) (*ProofTreeRenderModel, error) {
	if tree == nil {
		return nil, fmt.Errorf("proof node is nil")
	}

	model := &ProofTreeRenderModel{
		NodeID:      tree.ID,
		RuleApplied: tree.RuleApplied,
		Conclusion:  tree.Conclusion,
		ProofStatus: tree.Status,
		Hash:        tree.Hash,
	}

	// Recursively build premises
	model.Premises = make([]*ProofTreeRenderModel, len(tree.Premises))
	for i, premise := range tree.Premises {
		pmodel, err := buildProofTree(premise)
		if err != nil {
			return nil, err
		}
		model.Premises[i] = pmodel
	}

	return model, nil
}

// formatDuration converts time.Duration to human-readable string.
func formatDuration(d time.Duration) string {
	if d < time.Millisecond {
		return fmt.Sprintf("%.1fµs", float64(d)/float64(time.Microsecond))
	}
	if d < time.Second {
		return fmt.Sprintf("%.1fms", float64(d)/float64(time.Millisecond))
	}
	return fmt.Sprintf("%.2fs", d.Seconds())
}

// hashDerivation computes deterministic derivation hash.
func hashDerivation(d *semantic.Derivation) (string, error) {
	hasher := blake3.New()
	_, err := hasher.Write([]byte(d.Query))
	if err != nil {
		return "", err
	}
	_, err = hasher.Write([]byte(d.Result))
	if err != nil {
		return "", err
	}
	for _, step := range d.Steps {
		_, err := hasher.Write([]byte(step.Conclusion))
		if err != nil {
			return "", err
		}
	}
	return hex.EncodeToString(hasher.Sum(nil)[:32]), nil
}
```

### 2.4 ErrorToRenderModel

```go
// ErrorToRenderModel converts semantic error to renderable form.
func ErrorToRenderModel(err *semantic.Error) (*ErrorRenderModel, error) {
	if err == nil {
		return nil, fmt.Errorf("error is nil")
	}

	model := &ErrorRenderModel{
		ErrorCode:          err.Code,
		ErrorMessage:       err.Message,
		ErrorType:          classifyError(err),
		Stage:              err.Stage,
		FailedEntityID:     err.FailedEntityID,
		FailedEntityType:   err.FailedEntityType,
		Timestamp:          err.Timestamp,
		StackTrace:         err.StackTrace,
		Recoverable:        isRecoverable(err),
	}

	// Categorize violation
	if err.ViolationKind != "" {
		model.ViolationKind = err.ViolationKind
		model.ViolationDescription = describeViolation(err.ViolationKind, err.Details)
	}

	// Generate suggestion
	suggestion, steps := suggestRemedy(err.Code, err.Stage, err.ViolationKind)
	model.Suggestion = suggestion
	model.RemediationSteps = steps

	// Set recovery path if recoverable
	if model.Recoverable {
		model.Recovery = &ErrorRecoveryPath{
			RecoveryAction: getRecoveryAction(err.Code),
			RetryPolicy:    getRetryPolicy(err.Code),
		}
	}

	return model, nil
}

// classifyError maps semantic error to ErrorType.
func classifyError(err *semantic.Error) string {
	switch {
	case strings.Contains(err.Code, "CONSTRAINT"):
		return "constraint_violation"
	case strings.Contains(err.Code, "NORM"):
		return "normalization_failure"
	case strings.Contains(err.Code, "CYCLE"):
		return "dag_cycle"
	case strings.Contains(err.Code, "PROOF"):
		return "proof_failure"
	case strings.Contains(err.Code, "TIMEOUT"):
		return "timeout"
	case strings.Contains(err.Code, "IO"):
		return "io_error"
	default:
		return "unknown_error"
	}
}

// isRecoverable determines if error is recoverable.
func isRecoverable(err *semantic.Error) bool {
	fatals := map[string]bool{
		"DAG_CYCLE":           true,  // Fatal: cannot recover from cycle
		"PROOF_DISCHARGED":    false, // Not an error
		"IMMUTABILITY_BREACH": true,  // Fatal
	}
	if fatal, ok := fatals[err.Code]; ok {
		return !fatal
	}
	// Most constraint violations are recoverable
	return !strings.Contains(err.Code, "FATAL")
}

// describeViolation returns human-readable violation description.
func describeViolation(kind, details string) string {
	descs := map[string]string{
		"C1": "Quantum state normalization failed: |α|² + |β|² ≠ 1",
		"C2": "Unitarity constraint violated: U†U ≠ I",
		"C3": "No-cloning invariant broken: duplicate quantum state",
		"C4": "CFT central charge too low: c < 1",
		"C5": "Ryu-Takayanagi entropy bound violated",
		"C6": "DAG contains cycle",
		"C7": "DAG has dangling edges",
		"C8": "Eggs are not semantically distinct",
	}
	if desc, ok := descs[kind]; ok {
		return desc
	}
	return details
}

// suggestRemedy returns suggestion and remediation steps.
func suggestRemedy(code, stage, violation string) (string, []string) {
	switch code {
	case "CONSTRAINT_C1_VIOLATION":
		return "Normalize quantum state amplitudes",
			[]string{
				"Compute norm: sqrt(|α|² + |β|²)",
				"Divide all amplitudes by norm",
				"Verify |α|² + |β|² = 1.0",
				"Retry crystallization",
			}

	case "DAG_CYCLE":
		return "Remove cyclic dependency in DAG",
			[]string{
				"Identify cycle: use Tarjan SCC algorithm",
				"Remove one edge from cycle",
				"Verify acyclicity",
				"Retry constraint propagation",
			}

	case "PROOF_TIMEOUT":
		return "Increase timeout or simplify query",
			[]string{
				"Increase derivation timeout from 30s to 60s",
				"Simplify query: break into sub-goals",
				"Check for infinite loops in rule set",
				"Retry with verbose logging",
			}

	default:
		return "Review error details and retry",
			[]string{
				"Inspect full error stack trace",
				"Check input data validity",
				"Verify all constraints are satisfiable",
				"Retry entire pipeline",
			}
	}
}

// getRecoveryAction returns appropriate recovery action.
func getRecoveryAction(code string) string {
	switch {
	case strings.Contains(code, "IO"):
		return "retry_io_operation"
	case strings.Contains(code, "TIMEOUT"):
		return "increase_timeout_and_retry"
	case strings.Contains(code, "CONSTRAINT"):
		return "relax_constraint_or_fix_input"
	default:
		return "manual_intervention_required"
	}
}

// getRetryPolicy returns retry policy string.
func getRetryPolicy(code string) string {
	if strings.Contains(code, "TIMEOUT") {
		return "exponential_backoff_3x"
	}
	if strings.Contains(code, "IO") {
		return "retry_3_times_linear_wait"
	}
	return "no_retry"
}
```

---

## Part 3: Mustache Templates

All templates stored in `templates/` directory. Logicless: no conditionals in Mustache syntax itself. Logic is pushed to model construction.

### 3.1 agent.mustache

```mustache
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Agent {{agent_name}} - {{omega_status}}</title>
  <link rel="stylesheet" href="/static/agent.css">
</head>
<body class="agent-render {{omega_status}}">

  <header class="agent-header">
    <h1>{{agent_name}}</h1>
    <div class="metadata">
      <span class="agent-id">ID: {{agent_id}}</span>
      <span class="state-id">State: {{state_id}}</span>
      <span class="revision">Rev {{revision}}</span>
      <span class="status-badge {{omega_status}}">{{omega_status}}</span>
    </div>
  </header>

  <section class="execution-summary">
    <h2>Execution Summary</h2>
    <dl>
      <dt>Start:</dt>
      <dd>{{start_time}}</dd>
      <dt>End:</dt>
      <dd>{{end_time}}</dd>
      <dt>Duration:</dt>
      <dd><strong>{{duration}}</strong></dd>
      <dt>Nonce:</dt>
      <dd><code>{{execution_nonce}}</code></dd>
    </dl>
    <div class="verification-status">
      {{#verified}}<span class="badge verified">✓ Verified</span>{{/verified}}
      {{#rejected}}<span class="badge rejected">✗ Rejected</span>{{/rejected}}
    </div>
  </section>

  {{#state}}
  <section class="state-section">
    {{>state}}
  </section>
  {{/state}}

  {{#tensor_states}}
  <section class="tensors-section">
    <h2>Tensor States ({{tensor_states.length}})</h2>
    {{#tensor_states}}
      {{>tensor}}
    {{/tensor_states}}
  </section>
  {{/tensor_states}}

  {{#derivations}}
  <section class="derivations-section">
    <h2>Derivations ({{derivations.length}})</h2>
    {{#derivations}}
      {{>derivation}}
    {{/derivations}}
  </section>
  {{/derivations}}

  {{#proof_tree}}
  <section class="proof-section">
    <h2>Proof Tree</h2>
    <div class="proof-tree">
      {{>proof_tree}}
    </div>
    <p class="proof-hash">Hash: <code>{{proof_hash}}</code></p>
  </section>
  {{/proof_tree}}

  {{#constraints}}
  <section class="constraints-section">
    <h2>Constraints ({{constraints.length}})</h2>
    <table class="constraint-table">
      <thead>
        <tr>
          <th>ID</th>
          <th>Name</th>
          <th>Type</th>
          <th>Level</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        {{#constraints}}
        <tr class="constraint-row {{status}}">
          <td><code>{{constraint_id}}</code></td>
          <td>{{constraint_name}}</td>
          <td>{{constraint_type}}</td>
          <td><span class="level-badge {{level}}">{{level}}</span></td>
          <td><span class="status-badge {{status}}">{{status}}</span></td>
        </tr>
        {{/constraints}}
      </tbody>
    </table>
  </section>
  {{/constraints}}

  {{#errors}}
  <section class="errors-section">
    <h2>Errors ({{errors.length}})</h2>
    {{#errors}}
      {{>error}}
    {{/errors}}
  </section>
  {{/errors}}

</body>
</html>
```

### 3.2 state.mustache

```mustache
<article class="state-card">
  <header class="state-header">
    <h3>{{state_name}}</h3>
    <span class="semantic-type">{{semantic_type}}</span>
    <div class="state-metadata">
      <code class="state-id">{{state_id}}</code>
      <span class="version">v{{state_version}}</span>
      {{#immutable}}<span class="badge immutable">Immutable</span>{{/immutable}}
      {{#sealed}}<span class="badge sealed">Sealed</span>{{/sealed}}
    </div>
  </header>

  <section class="state-content">
    {{#state_vector}}
    <div class="quantum-state state-vector">
      <h4>Quantum State Vector</h4>
      <div class="state-vector-info">
        <p>Dimension: <strong>{{dimension}}</strong></p>
        <p>Basis: <strong>{{basis}}</strong></p>
        {{#normalized}}
        <p>Normalized: ✓ (norm = {{norm_value}})</p>
        {{/normalized}}
      </div>

      <table class="amplitudes-table">
        <thead>
          <tr>
            <th>Index</th>
            <th>Basis</th>
            <th>Real</th>
            <th>Imag</th>
            <th>Magnitude</th>
            <th>Phase</th>
          </tr>
        </thead>
        <tbody>
          {{#amplitudes}}
          <tr class="amplitude-row">
            <td>{{index}}</td>
            <td><code>{{basis_state}}</code></td>
            <td>{{real}}</td>
            <td>{{imag}}</td>
            <td><strong>{{magnitude}}</strong></td>
            <td>{{phase}} rad</td>
          </tr>
          {{/amplitudes}}
        </tbody>
      </table>
    </div>
    {{/state_vector}}

    {{#density_matrix}}
    <div class="quantum-state density-matrix">
      <h4>Density Matrix</h4>
      <div class="density-matrix-info">
        <p>Dimension: <strong>{{dimension}}</strong></p>
        <p>Pure State: {{#is_pure_state}}✓ Yes{{/is_pure_state}}{{^is_pure_state}}✗ Mixed{{/is_pure_state}}</p>
        <p>Purity: <strong>{{purity}}</strong></p>
        <p>Trace: <strong>{{trace_value}}</strong></p>
      </div>

      <table class="matrix-table">
        <tbody>
          {{#elements}}
          <tr>
            <td class="matrix-element">
              <span class="re">{{real}}</span>
              <span class="im">+{{imag}}i</span>
              <span class="mag">({{magnitude}})</span>
            </td>
          </tr>
          {{/elements}}
        </tbody>
      </table>
    </div>
    {{/density_matrix}}
  </section>

  {{#constraints}}
  <section class="constraints-list">
    <h4>Constraints</h4>
    <div class="all-satisfied-indicator {{all_satisfied}}">
      {{#all_satisfied}}All constraints satisfied ✓{{/all_satisfied}}
      {{^all_satisfied}}⚠ Some constraints violated{{/all_satisfied}}
    </div>
    <ul class="constraints-ul">
      {{#constraints}}
      <li class="constraint-item {{satisfied}}">
        <code>{{constraint_id}}</code> — {{constraint_type}}
        {{#satisfied}}<span class="satisfied">✓</span>{{/satisfied}}
        {{^satisfied}}<span class="violated">✗ {{violation}}</span>{{/violated}}
      </li>
      {{/constraints}}
    </ul>
  </section>
  {{/constraints}}

  {{#bindings}}
  <section class="bindings-list">
    <h4>Variable Bindings</h4>
    <table class="bindings-table">
      <thead>
        <tr>
          <th>Variable</th>
          <th>Value</th>
          <th>Type</th>
          <th>Source Rule</th>
        </tr>
      </thead>
      <tbody>
        {{#bindings}}
        <tr class="binding-row">
          <td><code>{{variable}}</code></td>
          <td><code>{{value}}</code></td>
          <td>{{value_type}}</td>
          <td>{{source_rule}}</td>
        </tr>
        {{/bindings}}
      </tbody>
    </table>
  </section>
  {{/bindings}}

  <footer class="state-footer">
    <code class="state-hash">State Hash: {{state_hash}}</code>
    <code class="binding-hash">Binding Hash: {{binding_hash}}</code>
  </footer>
</article>
```

### 3.3 tensor.mustache

```mustache
<article class="tensor-card">
  <header class="tensor-header">
    <h4>{{tensor_name}}</h4>
    <span class="tensor-id"><code>{{tensor_id}}</code></span>
    <div class="tensor-props">
      <span class="rank">Rank {{rank}}</span>
      <span class="shape">Shape {{shape}}</span>
      <span class="element-type">{{element_type}}</span>
    </div>
  </header>

  <section class="tensor-info">
    <dl>
      <dt>Representation:</dt>
      <dd>{{representation_type}}</dd>
      <dt>Norm:</dt>
      <dd><strong>{{norm}}</strong></dd>
      {{#condition_number}}
      <dt>Condition Number:</dt>
      <dd>{{condition_number}}</dd>
      {{/condition_number}}
      {{#computed_from}}
      <dt>Derived From:</dt>
      <dd><code>{{computed_from}}</code></dd>
      {{/computed_from}}
    </dl>
  </section>

  {{#dense_representation}}
  <section class="dense-repr">
    <h5>Dense Representation</h5>
    <div class="layout {{row_major}}">
      <table class="dense-table">
        <tbody>
          {{#elements}}
          <tr><td class="element">{{.}}</td></tr>
          {{/elements}}
        </tbody>
      </table>
    </div>
  </section>
  {{/dense_representation}}

  {{#sparse_representation}}
  <section class="sparse-repr">
    <h5>Sparse Representation</h5>
    <p>Non-zero elements: <strong>{{non_zero_count}}</strong></p>
    <table class="sparse-coords">
      <thead>
        <tr>
          <th>Indices</th>
          <th>Value</th>
        </tr>
      </thead>
      <tbody>
        {{#coordinates}}
        <tr>
          <td><code>[{{indices}}]</code></td>
          <td><code>{{value}}</code></td>
        </tr>
        {{/coordinates}}
      </tbody>
    </table>
  </section>
  {{/sparse_representation}}

  {{#factorized_representation}}
  <section class="factorized-repr">
    <h5>Factorized Representation</h5>
    <p>Type: <strong>{{factorization_type}}</strong></p>

    {{#core_tensor}}
    <div class="core-tensor">
      <h6>Core Tensor</h6>
      <table class="factor-table">
        <tbody>
          {{#elements}}
          <tr><td>{{.}}</td></tr>
          {{/elements}}
        </tbody>
      </table>
    </div>
    {{/core_tensor}}

    {{#factors}}
    <div class="factor-block">
      <h6>{{factor_id}} (Mode {{mode}})</h6>
      <p>{{rows}} × {{cols}}</p>
      <table class="factor-data">
        <tbody>
          {{#data}}
          <tr><td><code>{{.}}</code></td></tr>
          {{/data}}
        </tbody>
      </table>
    </div>
    {{/factors}}
  </section>
  {{/factorized_representation}}

  <footer class="tensor-footer">
    <code class="tensor-hash">Tensor Hash: {{tensor_hash}}</code>
  </footer>
</article>
```

### 3.4 derivation.mustache

```mustache
<article class="derivation-card">
  <header class="derivation-header">
    <h4>{{derivation_name}}</h4>
    <span class="deriv-id"><code>{{derivation_id}}</code></span>
    <span class="proof-status {{proof_status}}">{{proof_status}}</span>
  </header>

  <section class="derivation-info">
    <div class="query-box">
      <h5>Query</h5>
      <pre class="curry-query"><code>{{curry_query}}</code></pre>
    </div>

    <div class="result-box">
      <h5>Result</h5>
      <div class="result-value">
        <span class="result-type">({{result_type}})</span>
        <code>{{result}}</code>
      </div>
    </div>

    <div class="timing">
      <dl>
        <dt>Query Time:</dt>
        <dd>{{query_time}}</dd>
        <dt>Execution:</dt>
        <dd><strong>{{execution_time}}</strong></dd>
      </dl>
    </div>
  </section>

  {{#proof_tree}}
  <section class="proof-tree">
    <h5>Proof Tree</h5>
    {{>proof_tree}}
  </section>
  {{/proof_tree}}

  {{#steps}}
  <section class="derivation-steps">
    <h5>Derivation Steps</h5>
    <ol class="steps-list">
      {{#steps}}
      <li class="derivation-step">
        <strong>{{step_id}}</strong>: {{rule_name}} ({{applied}})
        <div class="step-details">
          {{#premises}}
          <p class="premises">Premises: {{#premises}}<code>{{step_id}}</code> {{/premises}}</p>
          {{/premises}}
          <p class="conclusion">Conclusion: <code>{{conclusion}}</code></p>
          <p class="justification">Justification: <code>{{justification_hash}}</code></p>
        </div>
      </li>
      {{/steps}}
    </ol>
  </section>
  {{/steps}}

  {{#depends_on}}
  <section class="dependencies">
    <h5>Dependencies</h5>
    <ul class="deps-list">
      {{#depends_on}}
      <li><code>{{.}}</code></li>
      {{/depends_on}}
    </ul>
  </section>
  {{/depends_on}}

  <footer class="derivation-footer">
    <code class="deriv-hash">Derivation Hash: {{derivation_hash}}</code>
  </footer>
</article>
```

### 3.5 proof_tree.mustache (Recursive)

```mustache
<div class="proof-node {{proof_status}}" data-node-id="{{node_id}}">
  <div class="node-header">
    <span class="rule">{{rule_applied}}</span>
    <span class="status {{proof_status}}">{{proof_status}}</span>
  </div>

  <div class="conclusion">
    <code>{{conclusion}}</code>
  </div>

  {{#premises}}
  <div class="premises">
    <h6>Premises:</h6>
    <ul class="premise-list">
      {{#premises}}
      <li>
        {{>proof_tree}}
      </li>
      {{/premises}}
    </ul>
  </div>
  {{/premises}}

  <div class="node-hash">
    <code class="hash-value">{{hash}}</code>
  </div>
</div>
```

### 3.6 error.mustache

```mustache
<article class="error-card {{error_type}}">
  <header class="error-header">
    <h4>Error: {{error_code}}</h4>
    <span class="error-type {{error_type}}">{{error_type}}</span>
    <span class="stage">Stage: {{stage}}</span>
  </header>

  <section class="error-message">
    <p class="main-message">{{error_message}}</p>
  </section>

  {{#violation_kind}}
  <section class="violation">
    <h5>Constraint Violation</h5>
    <p class="violation-kind"><code>{{violation_kind}}</code></p>
    <p class="violation-desc">{{violation_description}}</p>
  </section>
  {{/violation_kind}}

  {{#failed_entity_id}}
  <section class="context">
    <h5>Context</h5>
    <dl>
      <dt>Failed Entity:</dt>
      <dd>
        <code>{{failed_entity_id}}</code> ({{failed_entity_type}})
      </dd>
      <dt>Timestamp:</dt>
      <dd>{{timestamp}}</dd>
    </dl>
  </section>
  {{/failed_entity_id}}

  {{#suggestion}}
  <section class="suggestion">
    <h5>Suggestion</h5>
    <p>{{suggestion}}</p>

    {{#remediation_steps}}
    <ol class="remediation-steps">
      {{#remediation_steps}}
      <li>{{.}}</li>
      {{/remediation_steps}}
    </ol>
    {{/remediation_steps}}
  </section>
  {{/suggestion}}

  {{#recovery}}
  <section class="recovery">
    <h5>Recovery Information</h5>
    {{#recoverable}}
    <p class="recoverable">✓ This error is recoverable.</p>
    {{/recoverable}}
    {{^recoverable}}
    <p class="unrecoverable">✗ This error is not recoverable. Manual intervention required.</p>
    {{/recoverable}}

    {{#recovery}}
    <dl>
      <dt>Recovery Action:</dt>
      <dd><code>{{recovery_action}}</code></dd>
      <dt>Retry Policy:</dt>
      <dd>{{retry_policy}}</dd>
      {{#rollback_state}}
      <dt>Rollback State:</dt>
      <dd><code>{{rollback_state}}</code></dd>
      {{/rollback_state}}
    </dl>
    {{/recovery}}
  </section>
  {{/recovery}}

  {{#stack_trace}}
  <section class="stack-trace">
    <h5>Stack Trace</h5>
    <pre><code>{{stack_trace}}</code></pre>
  </section>
  {{/stack_trace}}

</article>
```

---

## Part 4: Go html/template Backend

### 4.1 Template Manager

```go
package render

import (
	"fmt"
	"html/template"
	"os"
	"path/filepath"
	"sync"
)

// TemplateManager manages template compilation and caching.
type TemplateManager struct {
	templates map[string]*template.Template
	mu        sync.RWMutex
	baseDir   string
}

// NewTemplateManager creates a new template manager.
func NewTemplateManager(baseDir string) (*TemplateManager, error) {
	if _, err := os.Stat(baseDir); os.IsNotExist(err) {
		return nil, fmt.Errorf("template directory does not exist: %s", baseDir)
	}

	tm := &TemplateManager{
		templates: make(map[string]*template.Template),
		baseDir:   baseDir,
	}

	// Pre-compile all templates
	if err := tm.precompileTemplates(); err != nil {
		return nil, err
	}

	return tm, nil
}

// precompileTemplates loads and compiles all Mustache templates.
func (tm *TemplateManager) precompileTemplates() error {
	templateFiles := map[string]string{
		"agent":      "agent.mustache",
		"state":      "state.mustache",
		"tensor":     "tensor.mustache",
		"derivation": "derivation.mustache",
		"proof_tree": "proof_tree.mustache",
		"error":      "error.mustache",
	}

	for name, filename := range templateFiles {
		filePath := filepath.Join(tm.baseDir, filename)
		tmpl, err := template.ParseFiles(filePath)
		if err != nil {
			return fmt.Errorf("failed to parse %s: %w", filename, err)
		}

		// Register sub-templates for partials
		partials := []string{"state", "tensor", "derivation", "proof_tree", "error"}
		for _, partial := range partials {
			partialPath := filepath.Join(tm.baseDir, partial+".mustache")
			if _, err := os.Stat(partialPath); err == nil {
				if tmpl, err = tmpl.ParseFiles(partialPath); err != nil {
					return fmt.Errorf("failed to parse partial %s: %w", partial, err)
				}
			}
		}

		tm.templates[name] = tmpl
	}

	return nil
}

// RenderAgentModel renders an agent model to HTML.
func (tm *TemplateManager) RenderAgentModel(model *AgentRenderModel) (string, error) {
	tm.mu.RLock()
	tmpl, ok := tm.templates["agent"]
	tm.mu.RUnlock()

	if !ok {
		return "", fmt.Errorf("agent template not found")
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "agent.mustache", model); err != nil {
		return "", fmt.Errorf("failed to render agent: %w", err)
	}

	return buf.String(), nil
}

// RenderStateModel renders a state model to HTML.
func (tm *TemplateManager) RenderStateModel(model *StateRenderModel) (string, error) {
	tm.mu.RLock()
	tmpl, ok := tm.templates["state"]
	tm.mu.RUnlock()

	if !ok {
		return "", fmt.Errorf("state template not found")
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "state.mustache", model); err != nil {
		return "", fmt.Errorf("failed to render state: %w", err)
	}

	return buf.String(), nil
}

// RenderTensorModel renders a tensor model to HTML.
func (tm *TemplateManager) RenderTensorModel(model *TensorRenderModel) (string, error) {
	tm.mu.RLock()
	tmpl, ok := tm.templates["tensor"]
	tm.mu.RUnlock()

	if !ok {
		return "", fmt.Errorf("tensor template not found")
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "tensor.mustache", model); err != nil {
		return "", fmt.Errorf("failed to render tensor: %w", err)
	}

	return buf.String(), nil
}

// RenderDerivationModel renders a derivation model to HTML.
func (tm *TemplateManager) RenderDerivationModel(model *DerivationRenderModel) (string, error) {
	tm.mu.RLock()
	tmpl, ok := tm.templates["derivation"]
	tm.mu.RUnlock()

	if !ok {
		return "", fmt.Errorf("derivation template not found")
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "derivation.mustache", model); err != nil {
		return "", fmt.Errorf("failed to render derivation: %w", err)
	}

	return buf.String(), nil
}

// RenderErrorModel renders an error model to HTML.
func (tm *TemplateManager) RenderErrorModel(model *ErrorRenderModel) (string, error) {
	tm.mu.RLock()
	tmpl, ok := tm.templates["error"]
	tm.mu.RUnlock()

	if !ok {
		return "", fmt.Errorf("error template not found")
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "error.mustache", model); err != nil {
		return "", fmt.Errorf("failed to render error: %w", err)
	}

	return buf.String(), nil
}

// RenderJSON renders a model to JSON instead of HTML.
func (tm *TemplateManager) RenderJSON(model interface{}) (string, error) {
	b, err := json.MarshalIndent(model, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal JSON: %w", err)
	}
	return string(b), nil
}
```

### 4.2 Renderer Service

```go
package render

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sync"

	"github.com/quantum-holographic-eggs/internal/semantic"
)

// RendererService orchestrates rendering from semantic results to output.
type RendererService struct {
	templateMgr *TemplateManager
	mu          sync.RWMutex
}

// NewRendererService creates a new renderer service.
func NewRendererService(templateManager *TemplateManager) *RendererService {
	return &RendererService{
		templateMgr: templateManager,
	}
}

// RenderResult orchestrates full rendering pipeline.
type RenderResult struct {
	HTML      string                   `json:"html,omitempty"`
	JSON      string                   `json:"json,omitempty"`
	Canonical string                   `json:"canonical,omitempty"`
	Status    string                   `json:"status"`
	Error     *RenderError             `json:"error,omitempty"`
}

// RenderError encodes rendering errors.
type RenderError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Stage   string `json:"stage"`
}

// RenderAgent renders an agent execution.
func (rs *RendererService) RenderAgent(semanticAgent *semantic.Agent, formatType string) (*RenderResult, error) {
	result := &RenderResult{
		Status: "rendering",
	}

	// Convert to RenderModel
	renderModel, err := buildAgentRenderModel(semanticAgent)
	if err != nil {
		result.Error = &RenderError{
			Code:    "MODEL_CONVERSION_FAILED",
			Message: err.Error(),
			Stage:   "model_construction",
		}
		result.Status = "error"
		return result, err
	}

	// Route to appropriate format
	switch formatType {
	case "html":
		html, err := rs.templateMgr.RenderAgentModel(renderModel)
		if err != nil {
			result.Error = &RenderError{
				Code:    "TEMPLATE_RENDERING_FAILED",
				Message: err.Error(),
				Stage:   "template_execution",
			}
			result.Status = "error"
			return result, err
		}
		result.HTML = html

	case "json":
		jsonStr, err := rs.templateMgr.RenderJSON(renderModel)
		if err != nil {
			result.Error = &RenderError{
				Code:    "JSON_SERIALIZATION_FAILED",
				Message: err.Error(),
				Stage:   "json_encoding",
			}
			result.Status = "error"
			return result, err
		}
		result.JSON = jsonStr

	case "both":
		html, err := rs.templateMgr.RenderAgentModel(renderModel)
		if err != nil {
			result.Error = &RenderError{
				Code:    "HTML_RENDERING_FAILED",
				Message: err.Error(),
				Stage:   "template_execution",
			}
			result.Status = "error"
			return result, err
		}
		result.HTML = html

		jsonStr, err := rs.templateMgr.RenderJSON(renderModel)
		if err != nil {
			result.Error = &RenderError{
				Code:    "JSON_SERIALIZATION_FAILED",
				Message: err.Error(),
				Stage:   "json_encoding",
			}
			result.Status = "error"
			return result, err
		}
		result.JSON = jsonStr
	}

	result.Status = "success"
	return result, nil
}

// buildAgentRenderModel constructs top-level agent render model.
func buildAgentRenderModel(semanticAgent *semantic.Agent) (*AgentRenderModel, error) {
	model := &AgentRenderModel{
		AgentID:         semanticAgent.ID,
		AgentName:       semanticAgent.Name,
		StateID:         semanticAgent.StateID,
		Revision:        semanticAgent.Revision,
		OmegaStatus:     semanticAgent.OmegaStatus,
		Verified:        semanticAgent.Verified,
		Rejected:        semanticAgent.Rejected,
		RejectionReason: semanticAgent.RejectionReason,
		ProofHash:       semanticAgent.ProofHash,
		StartTime:       semanticAgent.StartTime,
		EndTime:         semanticAgent.EndTime,
		Duration:        formatDuration(semanticAgent.EndTime.Sub(semanticAgent.StartTime)),
		ExecutionNonce:  semanticAgent.ExecutionNonce,
	}

	// Build state
	if semanticAgent.State != nil {
		state, err := StateToRenderModel(semanticAgent.State)
		if err != nil {
			return nil, err
		}
		model.State = state
	}

	// Build tensor states
	model.TensorStates = make([]*TensorRenderModel, len(semanticAgent.Tensors))
	for i, t := range semanticAgent.Tensors {
		tensor, err := TensorToRenderModel(t)
		if err != nil {
			return nil, err
		}
		model.TensorStates[i] = tensor
	}

	// Build derivations
	model.Derivations = make([]*DerivationRenderModel, len(semanticAgent.Derivations))
	for i, d := range semanticAgent.Derivations {
		deriv, err := DerivationToRenderModel(d)
		if err != nil {
			return nil, err
		}
		model.Derivations[i] = deriv
	}

	// Build proof tree
	if semanticAgent.ProofTree != nil {
		tree, err := buildProofTree(semanticAgent.ProofTree)
		if err != nil {
			return nil, err
		}
		model.ProofTree = tree
	}

	// Build errors
	model.Errors = make([]*ErrorRenderModel, len(semanticAgent.Errors))
	for i, e := range semanticAgent.Errors {
		errModel, err := ErrorToRenderModel(e)
		if err != nil {
			return nil, err
		}
		model.Errors[i] = errModel
	}

	// Build constraints
	model.Constraints = make([]*ConstraintRenderModel, len(semanticAgent.Constraints))
	for i, c := range semanticAgent.Constraints {
		model.Constraints[i] = &ConstraintRenderModel{
			ConstraintID:   c.ID,
			ConstraintName: c.Name,
			ConstraintType: c.Type,
			Level:          c.Level,
			Definition:     c.Definition,
			Status:         c.Status,
			Details:        c.Details,
		}
	}

	return model, nil
}

// SanitizeHTML escapes unsafe HTML content.
func SanitizeHTML(s string) string {
	// Use html/template for escaping
	var buf bytes.Buffer
	template.HTMLEscape(&buf, []byte(s))
	return buf.String()
}
```

---

## Part 5: Integration Points

### 5.1 HTTP Handler

```go
package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/quantum-holographic-eggs/internal/render"
	"github.com/quantum-holographic-eggs/internal/semantic"
	"github.com/quantum-holographic-eggs/internal/store"
)

// RenderAgentHandler renders an agent execution result.
type RenderAgentHandler struct {
	store            store.Store
	rendererService  *render.RendererService
}

// NewRenderAgentHandler creates a new render handler.
func NewRenderAgentHandler(s store.Store, rs *render.RendererService) *RenderAgentHandler {
	return &RenderAgentHandler{
		store:           s,
		rendererService: rs,
	}
}

// ServeHTTP handles GET /api/render/agent/{id}.
func (h *RenderAgentHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	agentID := r.PathValue("id")
	if agentID == "" {
		http.Error(w, "agent id required", http.StatusBadRequest)
		return
	}

	// Query format (default: html)
	format := r.URL.Query().Get("format")
	if format == "" {
		format = "html"
	}

	// Retrieve semantic agent from store
	semanticAgent, err := h.store.GetAgent(r.Context(), agentID)
	if err != nil {
		http.Error(w, "agent not found", http.StatusNotFound)
		return
	}

	// Render
	result, err := h.rendererService.RenderAgent(semanticAgent, format)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{
			"error": err.Error(),
			"stage": "rendering",
		})
		return
	}

	// Write response
	switch format {
	case "html":
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write([]byte(result.HTML))

	case "json":
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)

	case "both":
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
	}

	w.WriteHeader(http.StatusOK)
}

// RenderStateHandler renders a semantic state.
type RenderStateHandler struct {
	store           store.Store
	rendererService *render.RendererService
}

// ServeHTTP handles GET /api/render/state/{id}.
func (h *RenderStateHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	stateID := r.PathValue("id")
	if stateID == "" {
		http.Error(w, "state id required", http.StatusBadRequest)
		return
	}

	// Retrieve semantic state
	semanticState, err := h.store.GetState(r.Context(), stateID)
	if err != nil {
		http.Error(w, "state not found", http.StatusNotFound)
		return
	}

	// Convert to render model
	renderModel, err := render.StateToRenderModel(semanticState)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Render HTML
	html, err := h.rendererService.templateMgr.RenderStateModel(renderModel)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(html))
}
```

---

## Part 6: End-to-End Examples

### 6.1 Complete Flow: JSON Input to HTML Output

```bash
# Input: Semantic agent result from Prolog pipeline
# Location: semantic/agents.json (stored)

# Step 1: Read semantic result
$ cat semantic/agents/agent-123.json
{
  "id": "agent-123",
  "name": "QUANTUM-LOGIC-AGENT",
  "omega_status": "success",
  "state": {
    "id": "state-456",
    "semantic_type": "state_vector",
    "quantum": {
      "state_vector": {
        "dimension": 2,
        "basis": "computational",
        "amplitudes": [
          {"real": 0.6, "imag": 0.0},
          {"real": 0.8, "imag": 0.0}
        ],
        "normalized": true
      }
    }
  },
  "constraints": [...],
  "verified": true
}

# Step 2: HTTP GET with format query
$ curl -i http://localhost:8080/api/render/agent/agent-123?format=html

HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Agent QUANTUM-LOGIC-AGENT - success</title>
  <link rel="stylesheet" href="/static/agent.css">
</head>
<body class="agent-render success">
  <header class="agent-header">
    <h1>QUANTUM-LOGIC-AGENT</h1>
    <div class="metadata">
      <span class="agent-id">ID: agent-123</span>
      <span class="state-id">State: state-456</span>
      <span class="revision">Rev 1</span>
      <span class="status-badge success">success</span>
    </div>
  </header>

  <section class="state-section">
    <article class="state-card">
      <header class="state-header">
        <h3>Quantum State</h3>
        <span class="semantic-type">state_vector</span>
        <div class="state-metadata">
          <code class="state-id">state-456</code>
          <span class="version">v1</span>
        </div>
      </header>

      <section class="state-content">
        <div class="quantum-state state-vector">
          <h4>Quantum State Vector</h4>
          <div class="state-vector-info">
            <p>Dimension: <strong>2</strong></p>
            <p>Basis: <strong>computational</strong></p>
            <p>Normalized: ✓ (norm = 1.0)</p>
          </div>

          <table class="amplitudes-table">
            <thead>
              <tr>
                <th>Index</th>
                <th>Basis</th>
                <th>Real</th>
                <th>Imag</th>
                <th>Magnitude</th>
                <th>Phase</th>
              </tr>
            </thead>
            <tbody>
              <tr class="amplitude-row">
                <td>0</td>
                <td><code>|0⟩</code></td>
                <td>0.6</td>
                <td>0</td>
                <td><strong>0.6</strong></td>
                <td>0 rad</td>
              </tr>
              <tr class="amplitude-row">
                <td>1</td>
                <td><code>|1⟩</code></td>
                <td>0.8</td>
                <td>0</td>
                <td><strong>0.8</strong></td>
                <td>0 rad</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="constraints-list">
        <h4>Constraints</h4>
        <div class="all-satisfied-indicator true">
          All constraints satisfied ✓
        </div>
        <ul class="constraints-ul">
          <li class="constraint-item true">
            <code>C1</code> — normalization
            <span class="satisfied">✓</span>
          </li>
        </ul>
      </section>

      <footer class="state-footer">
        <code class="state-hash">State Hash: abc123def456...</code>
        <code class="binding-hash">Binding Hash: xyz789...</code>
      </footer>
    </article>
  </section>

  <section class="constraints-section">
    <h2>Constraints (1)</h2>
    <table class="constraint-table">
      <thead>
        <tr>
          <th>ID</th>
          <th>Name</th>
          <th>Type</th>
          <th>Level</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr class="constraint-row satisfied">
          <td><code>C1</code></td>
          <td>Normalization</td>
          <td>quantum_constraint</td>
          <td><span class="level-badge FATAL">FATAL</span></td>
          <td><span class="status-badge satisfied">satisfied</span></td>
        </tr>
      </tbody>
    </table>
  </section>

</body>
</html>

# Step 3: Alternatively, JSON format
$ curl http://localhost:8080/api/render/agent/agent-123?format=json | jq .

{
  "agent_id": "agent-123",
  "agent_name": "QUANTUM-LOGIC-AGENT",
  "state_id": "state-456",
  "revision": 1,
  "omega_status": "success",
  "verified": true,
  "rejected": false,
  "proof_hash": "abc123...",
  "state": {
    "state_id": "state-456",
    "state_name": "Quantum State",
    "state_version": 1,
    "semantic_type": "state_vector",
    "state_vector": {
      "dimension": 2,
      "basis": "computational",
      "normalized": true,
      "norm_value": 1.0,
      "amplitudes": [
        {
          "index": 0,
          "basis_state": "|0⟩",
          "real": 0.6,
          "imag": 0.0,
          "magnitude": 0.6,
          "phase": 0.0
        },
        {
          "index": 1,
          "basis_state": "|1⟩",
          "real": 0.8,
          "imag": 0.0,
          "magnitude": 0.8,
          "phase": 0.0
        }
      ]
    },
    "constraints": [
      {
        "constraint_id": "C1",
        "constraint_type": "normalization",
        "bound_value": "1.0",
        "satisfied": true
      }
    ],
    "all_satisfied": true,
    "state_hash": "abc123def456...",
    "binding_hash": "xyz789..."
  },
  "constraints": [
    {
      "constraint_id": "C1",
      "constraint_name": "Normalization",
      "constraint_type": "quantum_constraint",
      "level": "FATAL",
      "definition": "|α|² + |β|² = 1",
      "status": "satisfied"
    }
  ],
  "start_time": "2026-09-22T14:30:00Z",
  "end_time": "2026-09-22T14:30:00.234Z",
  "duration": "234ms",
  "execution_nonce": "nonce-abc..."
}
```

### 6.2 Error Case: Constraint Violation

```bash
# Semantic error: normalization constraint violated

# Step 1: Semantic error result
{
  "error_code": "CONSTRAINT_C1_VIOLATION",
  "error_message": "Quantum state normalization failed",
  "error_type": "constraint_violation",
  "stage": "constraint_check",
  "violation_kind": "C1",
  "violation_description": "Normalization: |α|² + |β|² ≠ 1 (computed: 1.5)",
  "failed_entity_id": "state-789",
  "failed_entity_type": "state_vector",
  "suggestion": "Normalize quantum state amplitudes",
  "remediation_steps": [
    "Compute norm: sqrt(|α|² + |β|²)",
    "Divide all amplitudes by norm",
    "Verify |α|² + |β|² = 1.0",
    "Retry crystallization"
  ],
  "recoverable": true,
  "recovery": {
    "recovery_action": "relax_constraint_or_fix_input",
    "retry_policy": "no_retry"
  },
  "timestamp": "2026-09-22T14:31:00Z"
}

# Step 2: HTTP GET /api/render/error/error-999
HTML Output:
<article class="error-card constraint_violation">
  <header class="error-header">
    <h4>Error: CONSTRAINT_C1_VIOLATION</h4>
    <span class="error-type constraint_violation">constraint_violation</span>
    <span class="stage">Stage: constraint_check</span>
  </header>

  <section class="error-message">
    <p class="main-message">Quantum state normalization failed</p>
  </section>

  <section class="violation">
    <h5>Constraint Violation</h5>
    <p class="violation-kind"><code>C1</code></p>
    <p class="violation-desc">Normalization: |α|² + |β|² ≠ 1 (computed: 1.5)</p>
  </section>

  <section class="context">
    <h5>Context</h5>
    <dl>
      <dt>Failed Entity:</dt>
      <dd><code>state-789</code> (state_vector)</dd>
      <dt>Timestamp:</dt>
      <dd>2026-09-22T14:31:00Z</dd>
    </dl>
  </section>

  <section class="suggestion">
    <h5>Suggestion</h5>
    <p>Normalize quantum state amplitudes</p>
    <ol class="remediation-steps">
      <li>Compute norm: sqrt(|α|² + |β|²)</li>
      <li>Divide all amplitudes by norm</li>
      <li>Verify |α|² + |β|² = 1.0</li>
      <li>Retry crystallization</li>
    </ol>
  </section>

  <section class="recovery">
    <h5>Recovery Information</h5>
    <p class="recoverable">✓ This error is recoverable.</p>
    <dl>
      <dt>Recovery Action:</dt>
      <dd><code>relax_constraint_or_fix_input</code></dd>
      <dt>Retry Policy:</dt>
      <dd>no_retry</dd>
    </dl>
  </section>
</article>
```

### 6.3 Derivation Proof Tree

```bash
# Semantic derivation with nested proof tree

# Step 1: Semantic derivation JSON
{
  "id": "deriv-111",
  "name": "Bell State Verification",
  "query": "bell_state(|Φ+⟩, X, X)",
  "result": "true",
  "proof_status": "discharged",
  "steps": [
    {
      "id": "step-1",
      "rule_name": "entanglement_intro",
      "applied": "apply_bell_basis",
      "premises": [],
      "conclusion": "∃|ψ⟩. bell_state(|ψ⟩, X, X)"
    },
    {
      "id": "step-2",
      "rule_name": "correlation_check",
      "applied": "verify_correlations",
      "premises": [{"step_id": "step-1", "conclusion": "∃|ψ⟩. bell_state(|ψ⟩, X, X)"}],
      "conclusion": "P(X↑, X↑) = P(X↓, X↓) = 0.5"
    },
    {
      "id": "step-3",
      "rule_name": "qed",
      "applied": "conjunction",
      "premises": [{"step_id": "step-2"}],
      "conclusion": "bell_state(|Φ+⟩, X, X) ∧ validated"
    }
  ],
  "proof_tree": {
    "node_id": "root",
    "rule_applied": "entanglement_theorem",
    "conclusion": "bell_state(|Φ+⟩, X, X)",
    "status": "discharged",
    "premises": [
      {
        "node_id": "node-1",
        "rule_applied": "correlation_constraint",
        "conclusion": "P(X↑, X↑) + P(X↓, X↓) = 1.0",
        "status": "discharged",
        "premises": [
          {
            "node_id": "node-1-1",
            "rule_applied": "measurement_axiom",
            "conclusion": "outcome_distribution ∈ [0,1]",
            "status": "discharged"
          }
        ]
      }
    ]
  }
}

# Step 2: Rendered HTML
<article class="derivation-card">
  <header class="derivation-header">
    <h4>Bell State Verification</h4>
    <span class="deriv-id"><code>deriv-111</code></span>
    <span class="proof-status discharged">discharged</span>
  </header>

  <section class="derivation-info">
    <div class="query-box">
      <h5>Query</h5>
      <pre class="curry-query"><code>bell_state(|Φ+⟩, X, X)</code></pre>
    </div>

    <div class="result-box">
      <h5>Result</h5>
      <div class="result-value">
        <span class="result-type">(boolean)</span>
        <code>true</code>
      </div>
    </div>
  </section>

  <section class="proof-tree">
    <h5>Proof Tree</h5>
    <div class="proof-node discharged" data-node-id="root">
      <div class="node-header">
        <span class="rule">entanglement_theorem</span>
        <span class="status discharged">discharged</span>
      </div>
      <div class="conclusion">
        <code>bell_state(|Φ+⟩, X, X)</code>
      </div>

      <div class="premises">
        <h6>Premises:</h6>
        <ul class="premise-list">
          <li>
            <div class="proof-node discharged" data-node-id="node-1">
              <div class="node-header">
                <span class="rule">correlation_constraint</span>
                <span class="status discharged">discharged</span>
              </div>
              <div class="conclusion">
                <code>P(X↑, X↑) + P(X↓, X↓) = 1.0</code>
              </div>

              <div class="premises">
                <h6>Premises:</h6>
                <ul class="premise-list">
                  <li>
                    <div class="proof-node discharged" data-node-id="node-1-1">
                      <div class="node-header">
                        <span class="rule">measurement_axiom</span>
                        <span class="status discharged">discharged</span>
                      </div>
                      <div class="conclusion">
                        <code>outcome_distribution ∈ [0,1]</code>
                      </div>
                    </div>
                  </li>
                </ul>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </div>
  </section>

  <section class="derivation-steps">
    <h5>Derivation Steps</h5>
    <ol class="steps-list">
      <li class="derivation-step">
        <strong>step-1</strong>: entanglement_intro (apply_bell_basis)
        <div class="step-details">
          <p class="conclusion">Conclusion: <code>∃|ψ⟩. bell_state(|ψ⟩, X, X)</code></p>
        </div>
      </li>
      <li class="derivation-step">
        <strong>step-2</strong>: correlation_check (verify_correlations)
        <div class="step-details">
          <p class="premises">Premises: <code>step-1</code></p>
          <p class="conclusion">Conclusion: <code>P(X↑, X↑) = P(X↓, X↓) = 0.5</code></p>
        </div>
      </li>
      <li class="derivation-step">
        <strong>step-3</strong>: qed (conjunction)
        <div class="step-details">
          <p class="premises">Premises: <code>step-2</code></p>
          <p class="conclusion">Conclusion: <code>bell_state(|Φ+⟩, X, X) ∧ validated</code></p>
        </div>
      </li>
    </ol>
  </section>
</article>
```

---

## Part 7: Production Checklist

### 7.1 Pre-Deployment

- [ ] All Go types compile without errors
- [ ] Zero `map[string]interface{}` in codebase
- [ ] All template partials resolve correctly
- [ ] HTML escaping applied to all user-facing content
- [ ] Mustache syntax validated (no Go conditionals in templates)
- [ ] All rendering functions tested with unit tests
- [ ] Error paths tested (missing templates, nil models, bad data)
- [ ] Performance benchmarked (< 50ms per render)
- [ ] Content Security Policy headers set on all HTML responses
- [ ] CORS configured appropriately

### 7.2 Monitoring

- [ ] Log render errors to central logging (Sentry, etc.)
- [ ] Track render latency per template
- [ ] Alert on template parse failures
- [ ] Monitor JSON serialization errors
- [ ] Track constraint violation patterns

### 7.3 Security

- [ ] Input validation on all IDs
- [ ] HTML escaping enforced
- [ ] JSON path traversal prevented
- [ ] Rate limiting on render endpoints
- [ ] No debug information leaked in errors
- [ ] Sensitive hashes not exposed to UI

---

## References

- **Quantum Holographic EGG Crystallization**: `/README.md`
- **Semantic Domain**: `internal/semantic/model.go`
- **Template Directory**: `templates/`
- **Go html/template Docs**: https://pkg.go.dev/html/template
- **Mustache Specification**: https://mustache.github.io/
- **BLAKE3 Hashing**: `internal/crypto/blake3.go`

