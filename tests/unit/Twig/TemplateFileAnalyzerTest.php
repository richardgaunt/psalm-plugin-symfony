<?php

declare(strict_types=1);

namespace Psalm\SymfonyPsalmPlugin\Tests\Twig;

use PHPUnit\Framework\TestCase;
use Psalm\Codebase;
use Psalm\Config;
use Psalm\Internal\Analyzer\ProjectAnalyzer;
use Psalm\Internal\Provider\FileProvider;
use Psalm\Internal\Provider\Providers;
use Psalm\SymfonyPsalmPlugin\Twig\TemplateFileAnalyzer;
use Twig\Environment;
use Twig\Loader\ArrayLoader;

class TemplateFileAnalyzerTest extends TestCase
{
    protected function tearDown(): void
    {
        TemplateFileAnalyzer::setEnvironmentFactory(null);
        TemplateFileAnalyzer::setNameResolver(null);
        TemplateFileAnalyzer::setTemplateRootPath('templates');
    }

    public function testTheNameResolverNamesTheTemplates(): void
    {
        TemplateFileAnalyzer::setNameResolver(static fn (string $path): string => 'app:'.basename($path, '.html.twig'));

        self::assertSame('app:button', TemplateFileAnalyzer::getTemplateName('web/components/button/button.html.twig'));
        self::assertSame('app:index', TemplateFileAnalyzer::getTemplateName('templates/index.html.twig'));

        TemplateFileAnalyzer::setNameResolver(null);

        self::assertSame('web/components/button/button.html.twig', TemplateFileAnalyzer::getTemplateName('web/components/button/button.html.twig'));
        self::assertSame('index.html.twig', TemplateFileAnalyzer::getTemplateName('templates/index.html.twig'));
    }

    public function testTheEnvironmentFactoryGivesTheEnvironmentOnce(): void
    {
        $environment = new Environment(new ArrayLoader());
        $builds = 0;
        TemplateFileAnalyzer::setEnvironmentFactory(static function (Codebase $codebase) use ($environment, &$builds): Environment {
            ++$builds;

            return $environment;
        });

        $codebase = self::createCodebase();

        self::assertSame($environment, TemplateFileAnalyzer::getEnvironment($codebase));
        self::assertSame($environment, TemplateFileAnalyzer::getEnvironment($codebase));
        self::assertSame(1, $builds);
    }

    private static function createCodebase(): Codebase
    {
        /** @var Config $config */
        $config = (function () { return new self(); })->bindTo(null, Config::class)();

        return (new ProjectAnalyzer($config, new Providers(new FileProvider())))->getCodebase();
    }
}
