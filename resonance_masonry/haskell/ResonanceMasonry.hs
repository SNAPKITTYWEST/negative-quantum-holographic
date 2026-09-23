-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:a2aebfe3a7c7181439f7ef1dce5be52ddc813eaa7aade91c99f4334c75ffb3ca
--
module Main where

import qualified Data.Set as S
import Data.Set (Set)

-- Resonance Masonry: executable reference model.

data GeoRel = Orthogonal | Horizontal | Vertical | Symmetric | Congruent
  deriving (Eq, Ord, Show, Enum, Bounded)

data EthRel = RectitudeRel | EquityRel | IntegrityRel | SelfConsistent | Coherent
  deriving (Eq, Ord, Show, Enum, Bounded)

data Geometry = Geometry { geoRels :: Set GeoRel, loadBearing :: Bool }
  deriving (Eq, Show)

data Ethic = Ethic { ethRels :: Set EthRel, trustBearing :: Bool }
  deriving (Eq, Show)

data OpState = OpState { stone :: Int, geometry :: Geometry }
  deriving (Eq, Show)

data SpState = SpState { agent :: Int, ethic :: Ethic }
  deriving (Eq, Show)

data Transition = Transition
  { protectedFrom, protectedTo :: Set Int
  , authFrom, authTo, granted :: Set Int
  , privileged, dark, authorized :: Bool
  } deriving (Eq, Show)

allowedGeo, allowedEth :: Set GeoRel
allowedGeo = S.fromList [Orthogonal, Horizontal, Vertical, Symmetric]

psiRel :: GeoRel -> EthRel
psiRel Orthogonal  = RectitudeRel
psiRel Horizontal  = EquityRel
psiRel Vertical    = IntegrityRel
psiRel Symmetric   = SelfConsistent
psiRel Congruent   = Coherent

psiAgent :: Int -> Int
psiAgent = id

psiGeometry :: Geometry -> Ethic
psiGeometry g = Ethic (S.map psiRel (geoRels g)) (loadBearing g)

psi :: OpState -> SpState
psi s = SpState (psiAgent (stone s)) (psiGeometry (geometry s))

opInvariant :: Bool -> OpState -> Bool
opInvariant nonEmpty s =
  geoRels (geometry s) `S.isSubsetOf` allowedGeo &&
  (not nonEmpty || not (S.null (geoRels (geometry s)))) &&
  loadBearing (geometry s)

spInvariant :: SpState -> Bool
spInvariant s =
  ethRels (ethic s) `S.isSubsetOf` allowedEth &&
  trustBearing (ethic s)

lightMasonry :: SpState -> Bool
lightMasonry s = spInvariant s && not (S.null (ethRels (ethic s)))

care :: Transition -> Bool
care t =
  protectedTo t == protectedFrom t &&
  authTo t `S.isSubsetOf` (authFrom t `S.union` granted t)

darkCrossing :: Transition -> Bool
darkCrossing t = dark t && not (care t)

-- SUBLEQ machine --------------------------------------------------

type Addr = Int
type Word = Integer
type Memory = [Word]

data Machine = Machine { pc :: Addr, memory :: Memory }
  deriving (Eq, Show)

readMem :: Memory -> Addr -> Word
readMem m a = if a >= 0 && a < length m then m !! a else 0

writeMem :: Memory -> Addr -> Word -> Memory
writeMem m a v
  | a < 0 = m
  | otherwise = take a m ++ [v] ++ drop (a + 1) m

stepSubleq :: Machine -> Machine
stepSubleq m =
  let p = pc m
      a = fromIntegral (readMem (memory m) (p + 0))
      b = fromIntegral (readMem (memory m) (p + 1))
      c = fromIntegral (readMem (memory m) (p + 2))
      oldB = readMem (memory m) b
      oldA = readMem (memory m) a
      newB = oldB - oldA
      mem' = writeMem (memory m) b newB
      pc' = if newB <= 0 then c else p + 3
  in Machine pc' mem'

tracePC :: Int -> Machine -> [Addr]
tracePC n m0 = take n (go m0)
  where
    go m = pc m : go (stepSubleq m)

firstCycle :: [Addr] -> Maybe Int
firstCycle xs = go 1
  where
    go k | k >= length xs = Nothing
         | periodic k xs = Just k
         | otherwise = go (k + 1)
    periodic k ys = all (uncurry (==))
      [ (ys !! i, ys !! (i + k)) | i <- [0 .. length ys - k - 1] ]

resonanceFrequency :: Double -> Int -> Maybe Double
resonanceFrequency instructionHz k
  | k <= 0 = Nothing
  | otherwise = Just (instructionHz / fromIntegral k)

-- A deterministic example: unconditional-ish branch to address 0.
exampleMachine :: Machine
exampleMachine = Machine 0 [0,0,0]

main :: IO ()
main = do
  let g = Geometry (S.fromList [Orthogonal, Horizontal, Vertical, Symmetric]) True
      s = OpState 1 g
      sp = psi s
      t = Transition (S.singleton 1) (S.singleton 1)
                     (S.singleton 7) (S.singleton 7) S.empty True False True
      pcs = tracePC 12 exampleMachine
  putStrLn "RESONANCE MASONRY"
  print ("OpInvariant(A)" , opInvariant True s)
  print ("LightMasonry(Psi s)", lightMasonry sp)
  print ("CARE", care t)
  print ("DarkCrossing", darkCrossing t)
  print ("PC trace", pcs)
  print ("PC period", firstCycle pcs)
  print ("resonance @ 1GHz", firstCycle pcs >>= resonanceFrequency 1.0e9)
