{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- |
-- Module:      Data.Stencil
-- Copyright:   Tobias Florek 2014
-- License:     BSD3
--
-- Maintainer:  Tobias Florek <tob@butter.sh>
-- Stability:   experimental
-- Portability: unknown
--
-- The "Text.Stencil" interface for translation 'Text' from it's template
-- syntax, to a generated value — based on the data that was given.

module Text.Stencil
( renderTemplate
, renderTemplate'
, renderTemplate''
, loadTemplatesInDir
, loadTemplates
, continueHandler
, module Text.Stencil.Types
) where

import Text.Stencil.Compiler
import Text.Stencil.Parse
import Text.Stencil.ResolveIncludes
import Text.Stencil.Types

import Control.Applicative  (many, (<$>))
import Control.Exception    (SomeException, try)
import Data.Aeson           (decode')
import Data.Attoparsec.Text.Lazy (eitherResult, parse)
import Data.HashMap.Strict  (HashMap)
import Data.Text            (Text)
import System.Directory     (doesFileExist, getCurrentDirectory)
import System.FilePath      (normalise, (</>))

import qualified Data.ByteString.Lazy   as BL
import qualified Data.Text              as T
import qualified Data.Text.Lazy.IO      as TLIO
import qualified Data.Text.Lazy         as TL
import qualified Data.Text.Lazy.Builder as TB

-- | Renders a template
renderTemplate :: (Functor m, Monad m)
               => (FilePath -> m (Maybe TL.Text))
               -- ^ load templates that are included
               -> (StencilError -> Either StencilError Text)
               -- ^ error handler
               -> HashMap Text Value
               -- ^ Data map for variables inside
               --   a given template
               -> TL.Text
               -- ^ Template
               -> m (Either StencilError TL.Text)
renderTemplate loader handler ctx tmpl =
    case eitherResult $ parse (many templateParser) tmpl of
      Right r -> do
          eResolved <- resolveIncludes loader (tokens r)
          return $ case eResolved of
            Left err -> TL.fromStrict <$> handler err
            Right resolved ->
                TB.toLazyText . rawRenderer <$> renderParsedTemplate handler ctx resolved
      Left err -> return $ TL.fromStrict <$> handler (InvalidTemplate "(inline)" err)


loadTemplatesInDir :: FilePath -> Loader IO
loadTemplatesInDir basePath f =
    doesFileExist file >>= \case
      False -> return Nothing
      True  -> try' $ TLIO.readFile file
  where
    file = normalise $ basePath </> f
    try' = fmap (either (\(_ :: SomeException) -> Nothing) Just) . try

loadTemplates :: Loader IO
loadTemplates file = getCurrentDirectory >>= flip loadTemplatesInDir file

continueHandler :: StencilError -> Either StencilError Text
continueHandler (InvalidTemplate _ _) = Right T.empty
continueHandler (InvalidTemplateFile _ _) = Right T.empty
continueHandler (LookupError _) = Right T.empty
continueHandler (NoSuchInclude err) = Right (T.pack err)
continueHandler (ManyErrors _) = Right T.empty

-- | Similar to renderTemplate, only it takes JSON 'Text' instead of
-- a 'HashMap'
renderTemplate' :: FilePath -- ^ file with JSON data, for variables inside a given
                        --   template
                -> TL.Text -- ^ Template
                -> IO TL.Text
renderTemplate' file tpl =
  decode' <$> BL.readFile file >>= \case
    (Just ctx) -> either err id <$>
        renderTemplate loadTemplates continueHandler ctx tpl
    Nothing     -> error "renderTemplate': could not decode JSON."
  where err e = error $ "renderTemplate': something went wrong: " ++ show e



-- | Similar to renderTemplate, only it takes JSON 'Text' instead of
-- a 'HashMap'
renderTemplate'' :: BL.ByteString -- ^ file with JSON data, for variables inside a given
                        --   template
                -> TL.Text -- ^ Template
                -> IO TL.Text
renderTemplate'' json tpl =
  case decode' json of
    (Just ctx) -> either err id <$>
        renderTemplate loadTemplates continueHandler ctx tpl
    Nothing     -> error "renderTemplate': could not decode JSON."
  where err e = error $ "renderTemplate': something went wrong: " ++ show e

