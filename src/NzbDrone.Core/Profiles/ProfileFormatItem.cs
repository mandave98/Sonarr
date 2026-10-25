using NzbDrone.Core.CustomFormats;
using NzbDrone.Core.Datastore;

namespace NzbDrone.Core.Profiles
{
    public class ProfileFormatItem : IEmbeddedDocument
    {
        public CustomFormat Format { get; set; }
        public int Score { get; set; }

        // Fork: show this format as a tag on episode rows when it matches the episode's file
        public bool AlwaysShow { get; set; }
    }
}
