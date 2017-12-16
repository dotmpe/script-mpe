
From projectdoc::

    repositories:
      <prefix>:
        status:
          <status1>: <value>
          <status2>:
            <sub1>: <value>
            <sub2>: <value>
            result: <value>
          result: <value>
        benchmarks:
          <benchmark>: value

``.cllct/stats.yml``::

    stats:
      <prefix>:
        <stat>:
          log: []
          last: {}

      (totals):
        <stat>: <accumulated last value>

