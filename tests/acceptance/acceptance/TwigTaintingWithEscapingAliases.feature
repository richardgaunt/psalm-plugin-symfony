@symfony-common
Feature: Twig tainting with escaping-filter aliases

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
          </pluginClass>
        </plugins>
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
      use Twig\TwigFilter;

      final class TwigExtension extends AbstractExtension
      {
          #[\Override]
          public function getFilters(): array
          {
              return [new TwigFilter('app_escape', [self::class, 'escape'])];
          }

          public static function escape(string $value): string
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

  Scenario: A filter not registered as an escaping alias keeps the taints its callable keeps
    Given I have the following code
      """
      echo twig()->render('index.html.twig', ['untrusted' => $_GET['untrusted']]);
      """
    And I have the following "index.html.twig" template
      """
      <h1>{{ untrusted|app_escape|raw }}</h1>
      """
    When I run Psalm with taint analysis
    Then I see these errors
      | Type                  | Message                                    |
      | TaintedHtml           | Detected tainted HTML                      |
      | TaintedTextWithQuotes | Detected tainted text with possible quotes |
    And I see no other errors

  Scenario: A tainted parameter goes through a filter registered as an escaping alias and is displayed with the raw filter
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
            <twigEscapingFilter>app_escape</twigEscapingFilter>
          </pluginClass>
        </plugins>
      </psalm>
      """
    And I have the following code
      """
      echo twig()->render('index.html.twig', ['untrusted' => $_GET['untrusted']]);
      """
    And I have the following "index.html.twig" template
      """
      <h1>{{ untrusted|app_escape|raw }}</h1>
      """
    When I run Psalm with taint analysis
    And I see no errors
