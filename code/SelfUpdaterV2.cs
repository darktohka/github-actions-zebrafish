using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using GitHub.DistributedTask.WebApi;
using GitHub.Runner.Common;
using GitHub.Runner.Common.Util;
using GitHub.Runner.Sdk;
using GitHub.Services.Common;
using GitHub.Services.WebApi;

namespace GitHub.Runner.Listener
{
    [ServiceLocator(Default = typeof(SelfUpdaterV2))]
    public interface ISelfUpdaterV2 : IRunnerService
    {
        bool Busy { get; }
        Task<bool> SelfUpdate(RunnerRefreshMessage updateMessage, IJobDispatcher jobDispatcher, bool restartInteractiveRunner, CancellationToken token);
    }
    public class SelfUpdaterV2 : RunnerService, ISelfUpdaterV2
    {
        public bool Busy { get; private set; }

        public Task<bool> SelfUpdate(RunnerRefreshMessage updateMessage, IJobDispatcher jobDispatcher, bool restartInteractiveRunner, CancellationToken token)
        {
            return Task.FromResult(true);
        }
    }
}
