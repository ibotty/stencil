{-# LANGUAGE OverloadedStrings #-}

module Text.StencilSpec (spec) where

import Text.Stencil

import Data.Text.Lazy   (Text, append, concat, unlines)
import Prelude          hiding (concat, unlines)
import System.IO.Unsafe (unsafePerformIO)
import Test.Hspec

renderer :: Text -> Text
renderer t = unsafePerformIO $ renderTemplate' file t
  where file = "test/json/test-data.json"
{-# NOINLINE renderer #-}

spec :: Spec
spec = do
  describe "renderTemplate" $ do
    it "identity at the end" $ do
      let endText  = "Template engine named {{ project }}"
          value    = renderer endText
          expected = "Template engine named stencil"

      value `shouldBe` expected

    it "identity at the beginning" $ do
      let beginText = "{{ language }} is what we are written in."
          value     = renderer beginText
          expected  = "haskell is what we are written in."

      value `shouldBe` expected

    it "identity in the middle" $ do
      let middleText = "All kept in a {{ ver-control }} repo, on Github."
          value      = renderer middleText
          expected   = "All kept in a git repo, on Github."

      value `shouldBe` expected

    it "multiple identities" $ do
      let multiText = append "{{ project }} is written in {{ language }}"
                             ", held in {{ ver-control }}."
          value     = renderer multiText
          expected  = "stencil is written in haskell, held in git."

      value `shouldBe` expected

    it "multiple line of identities" $ do
      let multiText = unlines
                        [ "{{ project }} is the name"
                        , "making template is my game"
                        , "if need something done faster"
                        , "you need something written in {{ language }}"
                        ]
          value     = renderer multiText
          expected  = unlines
                        [ "stencil is the name"
                        , "making template is my game"
                        , "if need something done faster"
                        , "you need something written in haskell"
                        ]

      value `shouldBe` expected

    it "object identity with brackets" $ do
      let objText  = "Templating with {{ template['name'] }} is easy."
          value    = renderer objText
          expected = "Templating with stencil is easy."

      value `shouldBe` expected

    it "object identity" $ do
      let objText  = "Templating with {{ template.name }} is easy."
          value    = renderer objText
          expected = "Templating with stencil is easy."

      value `shouldBe` expected

    it "mix of object a identity #1" $ do
      let mixText  = "My {{ project }} is your {{ template.name }}."
          value    = renderer mixText
          expected = "My stencil is your stencil."

      value `shouldBe` expected

    it "mix of object a identity #2" $ do
      let mixText  = "My {{ template.name }} is your {{ project }}."
          value    = renderer mixText
          expected = "My stencil is your stencil."

      value `shouldBe` expected

    it "list identity" $ do
      let arrText  = "stencil uses {{ libraries[0] }} for parsing."
          value    = renderer arrText
          expected = "stencil uses attoparsec for parsing."

      value `shouldBe` expected

    it "mix of list and identity" $ do
      let arrText  = "{{ project }} uses {{ libraries[1] }} for testing."
          value    = renderer arrText
          expected = "stencil uses hspec for testing."

      value `shouldBe` expected

    it "mix of list and object" $ do
      let arrText  = append "{{ template.name }} uses"
                            " {{ libraries[1] }} for testing."
          value    = renderer arrText
          expected = "stencil uses hspec for testing."

      value `shouldBe` expected

    it "true evaluated if" $ do
      let trueText = "{% if project %}{{ project }}{% endif %} is true"
          value    = renderer trueText
          expected = "stencil is true"

      value `shouldBe` expected

    -- it "false evaluated if" $ do
    --   let falseText = concat [ "{% if closed %}"
    --                          , "  stencil is closed source"
    --                          , "{% endif %}"
    --                          ]
    --       value     = renderer falseText
    --       expected  = ""
    --   value `shouldBe` expected

    it "check if object element exists with brackets" $ do
      let elemText = concat [ "{% if template['name'] %}"
                            , "  {{ template['name'] }} is the template."
                            , "{% endif %}"
                            ]
          value    = renderer elemText
          expected = "  stencil is the template."

      value `shouldBe` expected

    it "check if object element exists" $ do
      let elemText = concat [ "{% if template.name %}"
                            , "  {{ template.name }} is the template."
                            , "{% endif %}"
                            ]
          value    = renderer elemText
          expected = "  stencil is the template."

      value `shouldBe` expected

    it "check if list element exists" $ do
      let elemText = concat [ "{% if libraries[1] %}"
                            , concat [ "  {{ libraries[1] }} makes"
                                     , " testing enjoyable!"
                                     ]
                            , "{% endif %}"
                            ]
          value    = renderer elemText
          expected = "  hspec makes testing enjoyable!"

      value `shouldBe` expected

    -- it "false evaluated if else" $ do
    --   let falseText = concat [ "{% if closed %}"
    --                          , "  stencil is closed source"
    --                          , "{% else %}"
    --                          , "  stencil is open source"
    --                          , "{% endif %}"
    --                          ]
    --       value     = renderer falseText
    --       expected  = "  stencil is open source"
    --   value `shouldBe` expected

    -- it "false evaluated if else, for objects" $ do
    --   let elemText = concat [ "{% if template.license %}"
    --                         , "  {{ template.license }} is the license."
    --                         , "{% else %}"
    --                         , "  BSD3 is the license."
    --                         , "{% endif %}"
    --                         ]
    --       value    = renderer elemText
    --       expected = "  BSD3 is the license."
    --   value `shouldBe` expected

    it "loop over an array, single variable #1" $ do
      let loopText = concat [ "Some libraries used: "
                            , "{% for library in libraries %}"
                            , "{{ library }} "
                            , "{% endfor %}."
                            ]
          value    = renderer loopText
          expected = "Some libraries used: attoparsec hspec text ."

      value `shouldBe` expected

    it "loop over an array, single variable #2" $ do
      let loopText = unlines [ "Some libraries used:"
                             , "{% for library in libraries %}"
                             , "  * {{ library }}"
                             , "{% endfor %}"
                             ]
          value    = renderer loopText
          expected = unlines [ "Some libraries used:"
                             , "  * attoparsec"
                             , "  * hspec"
                             , "  * text"
                             ]

      value `shouldBe` expected

    it "loop over an array, with objects #1" $ do
      let withObj  = concat [ "{% for title in titles %}"
                            , "<a id=\"{{ title.id }}\">"
                            , "{{ title.name }}</a>"
                            , "{% endfor %}"
                            ]
          value    = renderer withObj
          expected = concat [ "<a id=\"stencil_the_template\">"
                            , "Stencil the Template</a>"
                            , "<a id=\"bdd_with_hspec\">BDD with Hspec</a>"
                            , "<a id=\"attoparsec_the_parser\">"
                            , "Attoparsec the Parser</a>"
                            ]

      value `shouldBe` expected

    it "loop over an array, with objects #2" $ do
      let withObj  = unlines [ "{% for title in titles %}"
                             , concat [ "<a id=\"{{ title.id }}\">"
                                      , "{{ title.name }}</a>"
                                      ]
                             , "{% endfor %}"
                             ]
          value    = renderer withObj
          expected = unlines [ concat [ "<a id=\"stencil_the_template\">"
                                      , "Stencil the Template</a>"
                                      ]
                             , "<a id=\"bdd_with_hspec\">BDD with Hspec</a>"
                             , concat [ "<a id=\"attoparsec_the_parser\">"
                                      , "Attoparsec the Parser</a>"
                                      ]
                             ]

      value `shouldBe` expected

    it "include a template alone" $ do
      let includeText = "{% include 'test/template/text.html' %}"
          value       = renderer includeText
          expected    = "Content in the file."

      value `shouldBe` expected

    it "include a template with surroundind markup" $ do
      let includeText = concat [ "<footer>"
                               , "{% include 'test/template/text.html' %}"
                               , "</footer>"
                               ]
          value       = renderer includeText
          expected    = "<footer>Content in the file.</footer>"

      value `shouldBe` expected

    it "include a template with surroundind markup #2" $ do
      let includeText = unlines [ "<ul>"
                                , concat [ "{% include "
                                         , "'test/template/template.html"
                                         , "' %}</ul>"
                                         ]
                                ]
          value       = renderer includeText
          expected    = unlines [ "<ul>"
                                , "  <li>attoparsec</li>"
                                , "  <li>hspec</li>"
                                , "  <li>text</li>"
                                , "</ul>"
                                ]

      value `shouldBe` expected
