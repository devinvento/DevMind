<?php
// brd-to-production phase 0 smoke tests for CodeIgniter 4 (vendor/bin/phpunit).
use CodeIgniter\Test\CIUnitTestCase;
use CodeIgniter\Test\FeatureTestTrait;

final class BrdSmokeTest extends CIUnitTestCase
{
    use FeatureTestTrait;

    public function test_TC_0_01_framework_loads(): void
    {
        $this->assertNotEmpty(config('App')->baseURL);
    }

    public function test_TC_0_02_home_route_responds(): void
    {
        $this->assertLessThan(500, $this->get('/')->response()->getStatusCode());
    }
}
