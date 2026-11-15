<?php
defined('BASEPATH') OR exit('No direct script access allowed');

/**
 * BRD delivery test runner (CLI only). Installed by the brd-to-production skill, phase 0.
 *
 *   php index.php brd_test_runner run <suite|all> [filter]
 *
 * Runs every class in tests/brd/<suite>/*Test.php that extends BrdTestCase.
 * Each test method runs inside a database transaction that is rolled back, so tests
 * never leave data behind (all tables must be InnoDB). Exit code 1 if anything fails.
 * PHP 7.4 compatible. Never deploy this controller to production: it refuses web requests,
 * and refuses databases whose hostname is not in BRD_TEST_DB_ALLOW.
 */
class Brd_test_runner extends CI_Controller
{
	public function __construct()
	{
		parent::__construct();
		if (!is_cli())
		{
			show_404();
		}
	}

	public function run($suite = 'all', $filter = '')
	{
		$this->load->database();
		$allow = getenv('BRD_TEST_DB_ALLOW');
		$allow = array_map('trim', explode(',', $allow ? $allow : 'localhost,127.0.0.1,db,mysql,mariadb,database,staging-db,test-db'));
		if (!in_array($this->db->hostname, $allow, TRUE))
		{
			fwrite(STDERR, "REFUSED: database host '{$this->db->hostname}' is not in BRD_TEST_DB_ALLOW\n");
			exit(2);
		}

		$root = FCPATH . 'tests/brd/';
		require_once $root . 'lib/BrdTestCase.php';
		$dirs = $suite === 'all' ? glob($root . '*', GLOB_ONLYDIR) : array($root . $suite);
		$totals = array('PASS' => 0, 'FAIL' => 0, 'ERROR' => 0, 'SKIP' => 0);
		$started = microtime(TRUE);
		echo "# brd_test_runner suite={$suite} filter={$filter} db={$this->db->hostname}/{$this->db->database} php=" . PHP_VERSION . ' at ' . date('c') . "\n";

		foreach ($dirs as $dir)
		{
			if (basename($dir) === 'lib' || basename($dir) === 'ui' || !is_dir($dir))
			{
				continue;
			}
			foreach (glob($dir . '/*Test.php') as $file)
			{
				$before = get_declared_classes();
				require_once $file;
				foreach (array_diff(get_declared_classes(), $before) as $class)
				{
					$ref = new ReflectionClass($class);
					if ($ref->isAbstract() || !$ref->isSubclassOf('BrdTestCase'))
					{
						continue;
					}
					foreach ($ref->getMethods(ReflectionMethod::IS_PUBLIC) as $m)
					{
						if (strpos($m->name, 'test') !== 0)
						{
							continue;
						}
						$tags = BrdTestCase::tags($m->getDocComment());
						$label = trim($tags['case'] . ' ' . $tags['ac']) . ' ' . $class . '::' . $m->name;
						if ($filter !== '' && stripos($label, $filter) === FALSE)
						{
							continue;
						}
						$status = $this->run_one($class, $m->name, $msg);
						$totals[$status]++;
						echo $status . ' ' . $label . ($msg !== '' ? ' -- ' . str_replace("\n", ' | ', $msg) : '') . "\n";
					}
				}
			}
		}
		printf("# totals PASS=%d FAIL=%d ERROR=%d SKIP=%d time=%.2fs\n", $totals['PASS'], $totals['FAIL'], $totals['ERROR'], $totals['SKIP'], microtime(TRUE) - $started);
		exit($totals['FAIL'] + $totals['ERROR'] > 0 ? 1 : 0);
	}

	private function run_one($class, $method, &$msg)
	{
		$msg = '';
		$this->db->trans_off(); // manual control below; CI's trans_start nesting would hide failures
		$this->db->query('START TRANSACTION');
		$t = new $class($this);
		try
		{
			$t->setUp();
			$t->$method();
			$t->tearDown();
			$status = 'PASS';
		}
		catch (BrdSkip $e)
		{
			$status = 'SKIP';
			$msg = $e->getMessage();
		}
		catch (BrdAssertionFailed $e)
		{
			$status = 'FAIL';
			$msg = $e->getMessage() . ' @' . $e->where;
		}
		catch (Throwable $e)
		{
			$status = 'ERROR';
			$msg = get_class($e) . ': ' . $e->getMessage() . ' @' . basename($e->getFile()) . ':' . $e->getLine();
		}
		$this->db->query('ROLLBACK');
		return $status;
	}
}
