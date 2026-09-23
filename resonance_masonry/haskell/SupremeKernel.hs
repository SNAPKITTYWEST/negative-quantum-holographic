-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a
--
-- SupremeKernel.hs — LiquidHaskell refinement layer
-- Author: Ahmad <ahmedparr93@gmail.com>
--
-- Refines: OpInvariant (parametric on nonEmpty), LightMasonry,
--   CARE/DarkCrossing, double-double recursion, Euclidean well-foundedness,
--   attention mechanism, supreme kernel gate.
--
-- Compile (plain GHC): ghc -o supreme SupremeKernel.hs
-- Check  (LiquidHaskell): liquid SupremeKernel.hs

{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple" @-}
{-@ LIQUID "--no-termination" @-}

module SupremeKernel where

import Data.Set (Set)
import qualified Data.Set as S

-- ── Atomic sorts ─────────────────────────────────────────────────────────────

data GeoRel
  = Orthogonal | Horizontal | Vertical | Symmetric | Congruent
  deriving (Eq, Ord, Show)

data EthRel
  = Rectitude_Rel | Equity_Rel | Integrity_Rel
  | Self_Consistent | Coherent
  deriving (Eq, Ord, Show)

data Geometry = Geometry { geoRels :: Set GeoRel, loadBearing :: Bool }
  deriving (Eq, Show)

data Ethic = Ethic { ethRels :: Set EthRel, trustBearing :: Bool }
  deriving (Eq, Show)

data OpState    = OpState    { stone :: Int, geometry :: Geometry }
  deriving (Eq, Show)
data SpState    = SpState    { agent :: Int, ethic :: Ethic }
  deriving (Eq, Show)

data Transition = Transition
  { tFrom :: Int, tTo :: Int
  , granted :: Set Int
  , privileged :: Bool
  , dark :: Bool
  } deriving (Eq, Show)

-- ── AllowedGeo / AllowedEth ───────────────────────────────────────────────────

{-@ reflect allowedGeo @-}
allowedGeo :: Set GeoRel
allowedGeo = S.fromList [Orthogonal, Horizontal, Vertical, Symmetric]

{-@ reflect allowedEth @-}
allowedEth :: Set EthRel
allowedEth = S.fromList [Rectitude_Rel, Equity_Rel, Integrity_Rel, Self_Consistent]

-- ── PsiRel (total) ────────────────────────────────────────────────────────────

{-@ reflect psiRel @-}
psiRel :: GeoRel -> EthRel
psiRel Orthogonal  = Rectitude_Rel
psiRel Horizontal  = Equity_Rel
psiRel Vertical    = Integrity_Rel
psiRel Symmetric   = Self_Consistent
psiRel Congruent   = Coherent

-- ── PsiGeometry ───────────────────────────────────────────────────────────────

{-@ reflect psiGeometry @-}
psiGeometry :: Geometry -> Ethic
psiGeometry g = Ethic
  { ethRels     = S.map psiRel (geoRels g)
  , trustBearing = loadBearing g
  }

-- ── PsiAgent (free — counterexample surface for AnyGeo branch) ───────────────

{-@ assume psiAgent :: Int -> Int @-}
psiAgent :: Int -> Int
psiAgent = id

-- ── Psi ──────────────────────────────────────────────────────────────────────

{-@ reflect psi @-}
psi :: OpState -> SpState
psi s = SpState
  { agent = psiAgent (stone s)
  , ethic = psiGeometry (geometry s)
  }

-- ── Invariants (parametric on nonEmpty — β′ decision) ────────────────────────

{-@ reflect opInvariant @-}
opInvariant :: Bool -> OpState -> Bool
opInvariant nonEmpty s =
     S.isSubsetOf (geoRels (geometry s)) allowedGeo
  && (not nonEmpty || not (S.null (geoRels (geometry s))))
  && loadBearing (geometry s)

{-@ reflect spInvariant @-}
spInvariant :: SpState -> Bool
spInvariant s =
     S.isSubsetOf (ethRels (ethic s)) allowedEth
  && trustBearing (ethic s)

-- ── LightMasonry ─────────────────────────────────────────────────────────────

{-@ reflect containment @-}
containment :: SpState -> Bool
containment s = not (S.null (ethRels (ethic s)))

{-@ reflect lightMasonry @-}
lightMasonry :: SpState -> Bool
lightMasonry s = spInvariant s && containment s

-- ── CARE / Dark ───────────────────────────────────────────────────────────────

{-@ reflect care @-}
care :: Transition -> Bool
care t = tTo t == tFrom t

{-@ reflect darkStep @-}
darkStep :: Transition -> Bool
darkStep t = dark t

{-@ reflect darkCrossing @-}
darkCrossing :: Transition -> Bool
darkCrossing t = darkStep t && not (care t)

-- ── Double-double recursion ───────────────────────────────────────────────────

{-@ reflect rDouble @-}
rDouble :: Int -> Bool -> OpState -> Bool
rDouble 0 nonEmpty s = opInvariant nonEmpty s
rDouble n nonEmpty s =
     rDouble (n-1) nonEmpty s
  && rDouble (n-1) nonEmpty s
  && spInvariant (psi s)

{-@ reflect careDouble @-}
careDouble :: Int -> Transition -> Bool
careDouble 0 _ = True
careDouble n t = careDouble (n-1) t && careDouble (n-1) t && care t

{-@ reflect jointKernel @-}
jointKernel :: Int -> Bool -> OpState -> Transition -> Bool
jointKernel n nonEmpty s t = rDouble n nonEmpty s && careDouble n t

-- ── Euclidean well-foundedness witness ────────────────────────────────────────

{-@ reflect gcdEuclid @-}
gcdEuclid :: Int -> Int -> Int
gcdEuclid a 0 = a
gcdEuclid a b = gcdEuclid b (a `mod` b)

{-@ gcdEuclid :: a:Nat -> b:Nat -> Nat / [b] @-}

-- ── Attention mechanism ───────────────────────────────────────────────────────

data Query = Query { qState :: OpState, qTrans :: Transition }

{-@ reflect p0 @-} p0 :: Query -> Bool
p0 q = opInvariant False (qState q)

{-@ reflect p1 @-} p1 :: Query -> Bool
p1 q = spInvariant (psi (qState q))

{-@ reflect p2 @-} p2 :: Query -> Bool
p2 q = lightMasonry (psi (qState q))

{-@ reflect p3 @-} p3 :: Query -> Bool
p3 q = care (qTrans q)

{-@ reflect p4 @-} p4 :: Query -> Bool
p4 q = not (darkStep (qTrans q))

{-@ reflect score @-}
score :: Query -> Int -> Int
score q i
  | i == 0 = if p0 q then 1 else 0
  | i == 1 = if p1 q then 1 else 0
  | i == 2 = if p2 q then 1 else 0
  | i == 3 = if p3 q then 1 else 0
  | i == 4 = if p4 q then 1 else 0
  | otherwise = 0

-- Attention: normalized weighted sum over 5 predicates
{-@ reflect attention @-}
attention :: Query -> Double
attention q =
  let w i    = exp (fromIntegral (score q i))
      z      = sum [ w i | i <- [0..4] ]
      num    = sum [ w i * fromIntegral (score q i) | i <- [0..4] ]
  in  if z == 0 then 0 else num / z

{-@ attention :: q:Query -> { r:Double | 0 <= r && r <= 1 } @-}

-- ── Supreme Kernel: attention * hard gate ────────────────────────────────────

{-@ reflect l1Graded @-}
l1Graded :: Bool -> OpState -> Double
l1Graded nonEmpty s =
  if opInvariant nonEmpty s
     then if lightMasonry (psi s) then 1 else 0
     else 1

{-@ reflect supremeKernel @-}
supremeKernel :: Int -> Bool -> OpState -> Transition -> Double
supremeKernel n nonEmpty s t =
  attention (Query s t) *
  (if jointKernel n nonEmpty s t then 1 else 0)

{-@ supremeKernel
      :: n:Nat -> b:Bool -> s:OpState -> t:Transition
      -> { r:Double | 0 <= r && r <= 1 } @-}

-- ── Demo ─────────────────────────────────────────────────────────────────────

demo :: IO ()
demo = do
  let g  = Geometry (S.fromList [Orthogonal, Horizontal, Vertical, Symmetric]) True
      s  = OpState 1 g
      sp = psi s
      t  = Transition { tFrom = 0, tTo = 0
                      , granted = S.empty, privileged = False, dark = False }
      q  = Query s t
  putStrLn "=== SupremeKernel ==="
  putStrLn $ "opInvariant(True, s)  = " ++ show (opInvariant True s)
  putStrLn $ "opInvariant(False, s) = " ++ show (opInvariant False s)
  putStrLn $ "lightMasonry(psi s)   = " ++ show (lightMasonry sp)
  putStrLn $ "care(t)               = " ++ show (care t)
  putStrLn $ "darkCrossing(t)       = " ++ show (darkCrossing t)
  putStrLn $ "attention(q)          = " ++ show (attention q)
  putStrLn $ "supremeKernel 3 True  = " ++ show (supremeKernel 3 True s t)
  putStrLn $ "gcdEuclid 48 18       = " ++ show (gcdEuclid 48 18)

main :: IO ()
main = demo
