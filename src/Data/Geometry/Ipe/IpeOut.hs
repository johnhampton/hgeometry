{-# LANGUAGE OverloadedStrings #-}
module Data.Geometry.Ipe.IpeOut where

import           Control.Applicative
import           Control.Lens
import           Data.Bifunctor
import           Data.Ext
import qualified Data.Foldable as F
import           Data.Geometry.Ball
import           Data.Geometry.Ipe.Attributes
import           Data.Geometry.Ipe.Types
import           Data.Geometry.LineSegment
import           Data.Geometry.Point
import           Data.Geometry.PolyLine
import           Data.Geometry.Transformation
import qualified Data.List.NonEmpty as NE
import           Data.Proxy
import qualified Data.Seq2 as S2
import           Data.Text(Text)
import qualified Data.Traversable as Tr
import           Data.Vinyl

--------------------------------------------------------------------------------

newtype IpeOut g i = IpeOut { asIpe :: g -> i }



-- | Given a Prism to convert a geometry object into an ipe geometry object,
-- the geometry object, and a record with its attributes, construct its corresponding
-- ipe Object.
asIpeObject         :: ( Rec (f r) ats ~ IpeObjectAttrElF r (it ats)
                       , RevIpeObjectValueElF i ~ it
                       , i ~ IpeObjectValueElF r (it ats)
                       )
                    => IpeOut g i
                    -> g -> Rec (f r) ats -> IpeObject r (it ats)
asIpeObject f g ats = asObject (asIpe f g) ats

-- | Given one of the ipe values, (i.e. a Path, IpeSymbol, etc.) and a Rec of
-- the appropriate corresponding type, construct an ipe Object from the two.
asObject     :: ( Rec (f r) ats ~ IpeObjectAttrElF r (it ats)
                , RevIpeObjectValueElF (IpeObjectValueElF r (it ats)) ~ it
                )
             => IpeObjectValueElF r (it ats)
             -> IpeObjectAttrElF r (it ats)
             -> IpeObject r (it ats)
asObject x r = IpeObject $ x :+ r


--------------------------------------------------------------------------------


mark   :: Text -> IpeOut (Point 2 r) (IpeSymbol r)
mark n = IpeOut $ flip Symbol n

diskMark :: IpeOut (Point 2 r) (IpeSymbol r)
diskMark = mark "mark/disk(sx)"



--------------------------------------------------------------------------------

lineSegment :: IpeOut (LineSegment 2 p r) (Path r)
lineSegment = fromPathSegment lineSegment'

lineSegment' :: IpeOut (LineSegment 2 p r) (PathSegment r)
lineSegment' = IpeOut $ PolyLineSegment . fromLineSegment . first (const ())


polyLine :: IpeOut (PolyLine 2 p r) (Path r)
polyLine = fromPathSegment polyLine'

polyLine' :: IpeOut (PolyLine 2 a r) (PathSegment r)
polyLine' = IpeOut $ PolyLineSegment . first (const ())


circle :: Floating r => IpeOut (Circle p r) (Path r)
circle = fromPathSegment circle'

circle' :: Floating r => IpeOut (Circle p r) (PathSegment r)
circle' = IpeOut circle''
  where
    circle'' (Circle (c :+ _) r) = EllipseSegment m
      where
        m = translation (toVec c) |.| uniformScaling (sqrt r) ^. transformationMatrix
        -- m is the matrix s.t. if we apply m to the unit circle centered at the origin, we
        -- get the input circle.


-- | Helper to construct a IpeOut g Path, for when we already have an IpeOut g PathSegment
fromPathSegment    :: IpeOut g (PathSegment r) -> IpeOut g (Path r)
fromPathSegment io = IpeOut $ Path . S2.l1Singleton . asIpe io