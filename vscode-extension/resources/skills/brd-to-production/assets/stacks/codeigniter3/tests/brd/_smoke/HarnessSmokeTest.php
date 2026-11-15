<?php
/**
 * Smoke test shipped with the harness. Proves the runner, the CI instance, the database and
 * the rollback work. Keep it in tests/brd/_smoke/.
 */
class HarnessSmokeTest extends BrdTestCase
{
	/** @case TC-0-01 @ac HARNESS.1 */
	public function test_ci_instance_and_db()
	{
		$this->assertTrue(is_object($this->CI->db), 'CI database loaded');
		$row = $this->db->query('SELECT 1 AS one')->row_array();
		$this->assertEquals(1, $row['one']);
	}

	/** @case TC-0-02 @ac HARNESS.2 */
	public function test_writes_are_rolled_back()
	{
		$key = $this->uid();
		$this->db->insert('app_config', array('key' => $key, 'value' => 'x'));
		$this->assertEquals(1, $this->rowCount('app_config', array('key' => $key)), 'row visible inside the test');
		$GLOBALS['brd_smoke_key'] = $key;
	}

	/** @case TC-0-03 @ac HARNESS.2 */
	public function test_previous_write_is_gone()
	{
		$key = isset($GLOBALS['brd_smoke_key']) ? $GLOBALS['brd_smoke_key'] : $this->skip('run after TC-0-02');
		$this->assertEquals(0, $this->rowCount('app_config', array('key' => $key)), 'row rolled back');
	}

	/** @case TC-0-04 @ac HARNESS.3 */
	public function test_php_version_matches_production()
	{
		// Set BRD_PROD_PHP to the production PHP version (major.minor, e.g. 7.4) so tests run on the same version.
		$prod = getenv('BRD_PROD_PHP');
		if (!$prod)
		{
			$this->skip('BRD_PROD_PHP not set; cannot check the runtime matches production');
		}
		$this->assertEquals($prod, PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION, 'tests run on the production PHP version');
	}
}
