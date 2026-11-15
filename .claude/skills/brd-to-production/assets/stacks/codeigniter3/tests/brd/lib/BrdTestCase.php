<?php
/**
 * Minimal assertion base for BRD tests (no Composer, PHP 7.4 compatible).
 * Tag each test method:  /** @case TC-1-01 @ac AC-002.1 *\/
 * $this->CI is the CodeIgniter instance: $this->CI->load->model('Sale'); $this->CI->Sale->...
 * $this->db is the database connection; everything is rolled back after each test.
 */
class BrdAssertionFailed extends Exception
{
	public $where = '';
}

class BrdSkip extends Exception
{
}

abstract class BrdTestCase
{
	protected $CI;
	protected $db;

	public function __construct($CI)
	{
		$this->CI = $CI;
		$this->db = $CI->db;
	}

	public function setUp()
	{
	}

	public function tearDown()
	{
	}

	public static function tags($doc)
	{
		$out = array('case' => '', 'ac' => '');
		if ($doc && preg_match('/@case\s+(\S+)/', $doc, $m)) $out['case'] = $m[1];
		if ($doc && preg_match('/@ac\s+([^\s*]+)/', $doc, $m)) $out['ac'] = '[' . $m[1] . ']';
		return $out;
	}

	protected function fail($message)
	{
		$e = new BrdAssertionFailed($message);
		foreach (debug_backtrace() as $f)
		{
			if (isset($f['file']) && strpos($f['file'], 'BrdTestCase.php') === FALSE)
			{
				$e->where = basename($f['file']) . ':' . $f['line'];
				break;
			}
		}
		throw $e;
	}

	protected function skip($why)
	{
		throw new BrdSkip($why);
	}

	protected function assertTrue($v, $m = 'expected true')
	{
		if ($v !== TRUE) $this->fail($m . ', got ' . var_export($v, TRUE));
	}

	protected function assertFalse($v, $m = 'expected false')
	{
		if ($v !== FALSE) $this->fail($m . ', got ' . var_export($v, TRUE));
	}

	protected function assertEquals($expected, $actual, $m = '')
	{
		if ($expected != $actual) $this->fail(trim($m . ' expected ' . var_export($expected, TRUE) . ', got ' . var_export($actual, TRUE)));
	}

	protected function assertSame($expected, $actual, $m = '')
	{
		if ($expected !== $actual) $this->fail(trim($m . ' expected identical ' . var_export($expected, TRUE) . ', got ' . var_export($actual, TRUE)));
	}

	protected function assertNull($v, $m = 'expected null')
	{
		if ($v !== NULL) $this->fail($m . ', got ' . var_export($v, TRUE));
	}

	protected function assertCount($n, $arr, $m = '')
	{
		$c = is_array($arr) || $arr instanceof Countable ? count($arr) : -1;
		if ($c !== $n) $this->fail(trim($m . " expected count {$n}, got {$c}"));
	}

	protected function assertContains($needle, $haystack, $m = '')
	{
		$ok = is_array($haystack) ? in_array($needle, $haystack) : strpos((string) $haystack, (string) $needle) !== FALSE;
		if (!$ok) $this->fail(trim($m . ' expected to contain ' . var_export($needle, TRUE)));
	}

	protected function assertThrows($fn, $m = 'expected an exception')
	{
		try
		{
			$fn();
		}
		catch (BrdAssertionFailed $e)
		{
			throw $e;
		}
		catch (Throwable $e)
		{
			return $e;
		}
		$this->fail($m);
	}

	/** Row count for a WHERE array, for data-integrity checks. */
	protected function rowCount($table, $where)
	{
		return (int) $this->db->where($where)->count_all_results($table);
	}

	/** Unique, recognisable test value so test data never collides with real data. */
	protected function uid($prefix = 'BRDTEST')
	{
		return $prefix . '-' . substr(md5(uniqid('', TRUE)), 0, 8);
	}
}
