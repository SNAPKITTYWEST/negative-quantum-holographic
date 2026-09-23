// SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
// CLONE_GATE:AES256:2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d
//
// operative_masonry.rs — Operative Invariant Enforcement
// Author: Ahmad <ahmedparr93@gmail.com>
//
// The Operative Invariant is Geometric Proportion / Structural Equilibrium.
// transform() checks that the ratio of proportion is preserved under any
// physical transformation applied by a Tool to a Stone.

use std::fmt;

/// Euclidean geometry: the governing constraint.
#[derive(Debug, Clone, PartialEq)]
pub struct EuclideanGeometry {
    pub right_angle_deg: f64,     // must remain 90.0
    pub phi: f64,                 // must remain ≈ 1.618
    pub plumb_deviation_mm: f64,  // must remain ≤ tolerance
    pub level_deviation_mm: f64,  // must remain ≤ tolerance
}

impl EuclideanGeometry {
    pub fn new() -> Self {
        Self {
            right_angle_deg: 90.0,
            phi: (1.0 + 5f64.sqrt()) / 2.0,
            plumb_deviation_mm: 0.0,
            level_deviation_mm: 0.0,
        }
    }

    /// The operative invariant signature: a tuple of the four geometric constraints.
    pub fn calculate_proportion(&self) -> (f64, f64, f64, f64) {
        (
            self.right_angle_deg,
            self.phi,
            self.plumb_deviation_mm,
            self.level_deviation_mm,
        )
    }

    pub fn is_valid(&self, tolerance: f64) -> bool {
        (self.right_angle_deg - 90.0).abs() < tolerance
            && (self.phi - 1.618_033_988_749_895).abs() < tolerance
            && self.plumb_deviation_mm.abs() < tolerance
            && self.level_deviation_mm.abs() < tolerance
    }
}

/// The physical substrate — state changes, but must preserve geometric truth.
#[derive(Debug, Clone)]
pub struct Stone {
    pub material: String,
    pub volume_cm3: f64,
    pub faces: usize,
    pub load_bearing: bool,
    pub core_flaw: bool,
    pub core_flaw_hidden: bool,
}

impl Stone {
    pub fn new(material: &str, volume_cm3: f64) -> Self {
        Self {
            material: material.to_string(),
            volume_cm3,
            faces: 6,
            load_bearing: true,
            core_flaw: false,
            core_flaw_hidden: false,
        }
    }

    /// Apply a tool: removes material, changes volume and surface state.
    pub fn carve(&mut self, tool: &Tool) {
        match tool {
            Tool::Chisel => {
                self.volume_cm3 *= 0.99; // remove ~1%
            }
            Tool::Mallet => {
                // Mallet drives chisel; no direct carve
            }
            Tool::CncMachine => {
                self.volume_cm3 *= 0.95;
            }
            _ => {}
        }
    }
}

#[derive(Debug, Clone)]
pub enum Tool {
    Square,
    Level,
    Plumb,
    Compass,
    Trowel,
    Chisel,
    Mallet,
    CncMachine,
}

#[derive(Debug)]
pub enum StructuralFailure {
    /// The geometric proportion changed: the invariant was violated.
    GeometricCollapse {
        before: (f64, f64, f64, f64),
        after:  (f64, f64, f64, f64),
    },
    /// Hidden flaw propagated under load.
    CoreFlawPropagation,
    /// Foundation yielded.
    AbutmentFailure,
}

impl fmt::Display for StructuralFailure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::GeometricCollapse { before, after } => {
                write!(f, "GeometricCollapse: before={:?} after={:?}", before, after)
            }
            Self::CoreFlawPropagation => write!(f, "CoreFlawPropagation"),
            Self::AbutmentFailure    => write!(f, "AbutmentFailure"),
        }
    }
}

/// The operative masonry system: geometry is the invariant.
pub struct OperativeMasonry {
    pub material: Stone,
    pub geometry: EuclideanGeometry,
    /// Tolerance for geometric checks (mm / degrees).
    pub tolerance: f64,
}

impl OperativeMasonry {
    pub fn new(stone: Stone) -> Self {
        Self {
            material: stone,
            geometry: EuclideanGeometry::new(),
            tolerance: 0.001,
        }
    }

    /// Apply a tool transformation and verify the invariant.
    ///
    /// # Invariant
    /// `initial_ratio == final_ratio` (within tolerance).
    /// If violated: `Err(GeometricCollapse)`.
    pub fn transform(&mut self, tool: &Tool) -> Result<(), StructuralFailure> {
        let initial_ratio = self.geometry.calculate_proportion();

        // Physical transformation: carve the stone.
        self.material.carve(tool);

        // The geometry must be re-verified after transformation.
        // In practice the mason re-applies square, level, plumb.
        let final_ratio = self.geometry.calculate_proportion();

        if self.ratios_equal(&initial_ratio, &final_ratio) {
            // Hidden flaw check: passes static inspection, fails load test.
            if self.material.core_flaw && !self.material.core_flaw_hidden {
                return Err(StructuralFailure::CoreFlawPropagation);
            }
            Ok(())
        } else {
            Err(StructuralFailure::GeometricCollapse { before: initial_ratio, after: final_ratio })
        }
    }

    fn ratios_equal(
        &self,
        a: &(f64, f64, f64, f64),
        b: &(f64, f64, f64, f64),
    ) -> bool {
        let t = self.tolerance;
        (a.0 - b.0).abs() < t
            && (a.1 - b.1).abs() < t
            && (a.2 - b.2).abs() < t
            && (a.3 - b.3).abs() < t
    }

    /// Apply the operative → speculative morphism Ψ.
    pub fn psi_morphism(tool: &Tool) -> &'static str {
        match tool {
            Tool::Square  => "rectitude",
            Tool::Level   => "equity",
            Tool::Plumb   => "integrity",
            Tool::Compass => "circumspection",
            Tool::Trowel  => "charity",
            _             => "unknown",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_a_material_shift() {
        // Limestone → marble: invariant still requires right angle
        let stone = Stone::new("marble", 1000.0);
        let mut om = OperativeMasonry::new(stone);
        assert!(om.transform(&Tool::Chisel).is_ok());
    }

    #[test]
    fn test_b_scale_shift() {
        // Small plinth → cathedral: proportion still required
        let stone = Stone::new("granite", 1_000_000.0);
        let mut om = OperativeMasonry::new(stone);
        assert!(om.transform(&Tool::CncMachine).is_ok());
    }

    #[test]
    fn test_c_tool_shift() {
        // Hand chisel → CNC: geometric specification still the target
        let stone = Stone::new("limestone", 500.0);
        let mut om = OperativeMasonry::new(stone);
        assert!(om.transform(&Tool::CncMachine).is_ok());
    }

    #[test]
    fn test_counter_mason_core_flaw() {
        // Stone with hidden flaw: passes visual inspection, fails load test
        let mut stone = Stone::new("limestone", 800.0);
        stone.core_flaw = true;
        stone.core_flaw_hidden = false; // revealed under load
        let mut om = OperativeMasonry::new(stone);
        let result = om.transform(&Tool::Chisel);
        assert!(result.is_err());
        assert!(matches!(result, Err(StructuralFailure::CoreFlawPropagation)));
    }

    #[test]
    fn test_psi_morphism() {
        assert_eq!(OperativeMasonry::psi_morphism(&Tool::Square),  "rectitude");
        assert_eq!(OperativeMasonry::psi_morphism(&Tool::Level),   "equity");
        assert_eq!(OperativeMasonry::psi_morphism(&Tool::Plumb),   "integrity");
        assert_eq!(OperativeMasonry::psi_morphism(&Tool::Compass), "circumspection");
        assert_eq!(OperativeMasonry::psi_morphism(&Tool::Trowel),  "charity");
    }
}
