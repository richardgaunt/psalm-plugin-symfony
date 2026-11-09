@symfony-common
Feature: Twig tainting with markup-returning callables

  Background:
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm totallyTyped="true" autoloader="autoload.php">
        <projectFiles>
          <directory name="."/>
          <directory name="templates"/>
          <ignoreFiles allowMissingFiles="true">
            <directory name="../../vendor" />
            <directory name="./cache" />
          </ignoreFiles>
        </projectFiles>
        <fileExtensions>
           <extension name=".php" />
           <extension name=".twig" checker="../../src/Twig/TemplateFileAnalyzer.php" scanner="../../src/Twig/TemplateFileScanner.php"/>
        </fileExtensions>
        <plugins>
          <pluginClass class="Psalm\SymfonyPsalmPlugin\Plugin">
            <containerXml>container.xml</containerXml>
            <twigMarkupType>App\SafeHtmlInterface</twigMarkupType>
          </pluginClass>
        </plugins>
        <issueHandlers>
          <PossiblyUnusedProperty errorLevel="info"/>
        </issueHandlers>
      </psalm>
      """
    And I have the following code in "container.xml"
      """
      <?xml version="1.0" encoding="utf-8"?>
      <container xmlns="http://symfony.com/schema/dic/services">
        <services>
          <service id="twig" class="Twig\Environment" public="true">
            <call method="addExtension"><argument type="service" id="app.twig_extension"/></call>
          </service>
          <service id="app.twig_extension" class="App\TwigExtension"/>
        </services>
      </container>
      """
    And I have the following code in "TwigExtension.php"
      """
      <?php

      namespace App;

      use Twig\Extension\AbstractExtension;
      use Twig\Markup;
      use Twig\TwigFilter;

      interface SafeHtmlInterface {}

      final class SafeHtml implements SafeHtmlInterface
      {
          public function __construct(public string $value) {}
      }

      final class TwigExtension extends AbstractExtension
      {
          #[\Override]
          public function getFilters(): array
          {
              return [
                  new TwigFilter('to_markup', [self::class, 'toMarkup']),
                  new TwigFilter('to_safe_html', [self::class, 'toSafeHtml']),
                  new TwigFilter('to_string', [self::class, 'toString']),
              ];
          }

          public static function toMarkup(string $value): Markup
          {
              return new Markup($value, 'UTF-8');
          }

          public static function toSafeHtml(string $value): SafeHtml
          {
              return new SafeHtml($value);
          }

          public static function toString(string $value): string
          {
              return $value;
          }
      }
      """
    And I have the following code in "autoload.php"
      """
      <?php

      require_once __DIR__.'/TwigExtension.php';
      """
    And I have the following code preamble
      """
      <?php

      use Twig\Environment;

      /**
       * @psalm-suppress InvalidReturnType
       * @return Environment
       * @psalm-capabilities read-props
       */
      function twig() {}
      """

  Scenario: A tainted parameter goes through a filter declared to return Twig markup, which autoescaping outputs as is
    Given I have the following code
      """
      echo twig()->render('index.html.twig', ['untrusted' => $_GET['untrusted']]);
      """
    And I have the following "index.html.twig" template
      """
      <h1>{{ untrusted|to_markup }}</h1>
      """
    When I run Psalm with taint analysis
    Then I see these errors
      | Type                  | Message                                    |
      | TaintedHtml           | Detected tainted HTML                      |
      | TaintedTextWithQuotes | Detected tainted text with possible quotes |
    And I see no other errors

  Scenario: A tainted parameter goes through a filter declared to return a registered markup type, which autoescaping outputs as is
    Given I have the following code
      """
      echo twig()->render('index.html.twig', ['untrusted' => $_GET['untrusted']]);
      """
    And I have the following "index.html.twig" template
      """
      <h1>{{ untrusted|to_safe_html }}</h1>
      """
    When I run Psalm with taint analysis
    Then I see these errors
      | Type                  | Message                                    |
      | TaintedHtml           | Detected tainted HTML                      |
      | TaintedTextWithQuotes | Detected tainted text with possible quotes |
    And I see no other errors

  Scenario: A tainted parameter goes through a filter not declared to return markup, and autoescaping escapes it
    Given I have the following code
      """
      echo twig()->render('index.html.twig', ['untrusted' => $_GET['untrusted']]);
      """
    And I have the following "index.html.twig" template
      """
      <h1>{{ untrusted|to_string }}</h1>
      """
    When I run Psalm with taint analysis
    And I see no errors
