<?php
// brd-to-production phase 0 smoke tests for Laravel (php artisan test / PHPUnit / Pest).
namespace Tests\brd\_smoke;

use Tests\TestCase;

class BrdSmokeTest extends TestCase
{
    public function test_TC_0_01_application_boots(): void
    {
        $this->assertTrue($this->app->isBooted());
    }

    public function test_TC_0_02_home_route_responds(): void
    {
        $this->assertLessThan(500, $this->get('/')->getStatusCode());
    }
}
