using System.Diagnostics;
using System.Xml.Linq;

namespace MarBasBrokerPgSQLGenTests
{
    [TestClass]
    public sealed class SolutionTest
    {
        private const string BranchProd = "main";
        private const string PackagePfx = "MarBas";
        private const string VersionDevSfx = "-dev";

        public TestContext? TestContext { get; set; }

        [TestMethod]
        public void PackageReferences_When_PrereleaseAndProductionBranch_Then_Fail()
        {
            var isProd = false;
            var mergeTarget = Environment.GetEnvironmentVariable("PR_TARGET_BRANCH");
            if (string.IsNullOrEmpty(mergeTarget))
            {
                var helper = new GitHelper();
                mergeTarget = helper.GetParentBranch(helper.GetCurrentBranch())?.Name;
            }
            isProd = BranchProd.Equals(mergeTarget, StringComparison.Ordinal);

            if (isProd)
            {
                var solutionDir = FindSolutionDirectory();
                var prjChecked = 0;
                if (null != solutionDir)
                {
                    foreach (var prjFile in Directory.GetFiles(solutionDir, "*.csproj", SearchOption.AllDirectories))
                    {
                        prjChecked++;
                        var prjDom = XElement.Load(prjFile);
                        foreach (var pkgRef in prjDom.Descendants("PackageReference").Where(x => (x.Attribute("Include")?.Value ?? string.Empty).StartsWith(PackagePfx)))
                        {
                            var ver = pkgRef.Attribute("Version")?.Value;
                            Assert.IsFalse(null == ver || ver.Contains(VersionDevSfx), $"{Path.GetFileName(prjFile)}: reference to pre-release package {pkgRef.Attribute("Include")?.Value}/{ver} is not allowed in production branch");
                        }
                    }
                }
                Assert.IsTrue(0 < prjChecked, "No CSPROJ files found in solution");
            }
        }

        private string FindSolutionDirectory()
        {
            var result = TestContext?.TestResultsDirectory;
            for (; null != result && !File.Exists(Path.Combine(result, "MarBasBrokerPgSQL.sln")); result = Path.GetDirectoryName(result))
            {
                // search loop
            }
            return result!;
        }

        private class GitHelper
        {
            private readonly IList<BranchNode> _branches = new List<BranchNode>();

            public IEnumerable<Branch> ListBranches()
            {
                if (0 == _branches.Count)
                {
                    var gitResp = RunGitCommand("branch --sort=-authordate");
                    if (0 != gitResp.Item1)
                    {
                        throw new AssertFailedException($"Git returned error {gitResp.Item1} ({gitResp.Item2})");
                    }
                    var lines = gitResp.Item2.Split(
                        new string[] { "\r\n", "\r", "\n" },
                        StringSplitOptions.None
                    );
                    foreach (var line in lines.Where(x => 0 < x.Length))
                    {
                        _branches.Add(new()
                        {
                            Name = line[2..],
                            IsCurrent = line.StartsWith("*", StringComparison.OrdinalIgnoreCase)
                        });
                    }
                }
                return _branches;
            }

            public Branch GetCurrentBranch()
            {
                return ListBranches().First(x => x.IsCurrent);
            }

            public Branch? GetParentBranch(Branch child)
            {
                _ = ListBranches();
                var node = _branches.FirstOrDefault(x => x == child || x.Name == child.Name);
                if (null == node || node.IsParentLoaded)
                {
                    return node?.Parent;
                }
                LoadBranchAncestors(node);
                return node.Parent;
            }

            private int LoadBranchAncestors(BranchNode node, BranchNode? contextNode = null)
            {
                var ancestors = new List<BranchNode>();
                foreach(var branch in _branches)
                {
                    if (node == branch || (null != contextNode && contextNode == branch))
                    {
                        continue;
                    }
                    var gitResp = RunGitCommand($"merge-base --is-ancestor {branch.Name} {node.Name}");
                    if (0 == gitResp.Item1)
                    {
                        ancestors.Add(branch);
                    }
                    else if (0 < gitResp.Item2.Length)
                    {
                        throw new AssertFailedException($"Git returned error {gitResp.Item1} ({gitResp.Item2})");
                    }
                }
                int longest = 0;
                foreach(var branch in ancestors)
                {
                    int parentPathLen = LoadBranchAncestors(branch, node);
                    if (longest <= parentPathLen)
                    {
                        longest = parentPathLen;
                        node.Parent = branch;
                    }
                }
                node.IsParentLoaded = true;
                return ancestors.Count;
            }

            private static Tuple<int, string> RunGitCommand(string arguments)
            {
                var startInfo = new ProcessStartInfo()
                {
                    FileName = "git",
                    Arguments = arguments,
                    UseShellExecute = false,
                    RedirectStandardError = true,
                    RedirectStandardOutput = true
                };

                var proc = new Process()
                {
                    StartInfo = startInfo
                };

                var started = proc.Start();
                if (!started)
                {
                    return new(-1, $"Failed to run {startInfo.FileName} {startInfo.Arguments}");
                }

                var stdout = proc.StandardOutput.EndOfStream ? "" : proc.StandardOutput.ReadToEnd();
                var stderr = proc.StandardError.EndOfStream ? "" : proc.StandardError.ReadToEnd();

                proc.WaitForExit();
                return new(proc.ExitCode, 0 == proc.ExitCode ? stdout : stderr);
            }
        }

        private class Branch
        {
            public string? Name { get; set; }
            public bool IsCurrent { get; set; }
        }

        private class BranchNode: Branch
        {
            public BranchNode? Parent { get; set; }
            public bool IsParentLoaded { get; set; }
        }
    }
}