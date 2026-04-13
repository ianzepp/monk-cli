use clap::{Args, Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(name = "monk")]
#[command(about = "CLI for the Monk API")]
pub struct Cli {
    #[command(flatten)]
    pub globals: GlobalOptions,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Args, Debug, Default)]
pub struct GlobalOptions {
    /// Override the Monk API base URL
    #[arg(long = "base-url")]
    pub base_url: Option<String>,

    /// Override the stored bearer token
    #[arg(long)]
    pub token: Option<String>,

    /// Override the preferred response format
    #[arg(long)]
    pub format: Option<String>,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    /// Public surfaces and discovery
    Public(PublicCommand),
    /// Authentication and tenant bootstrap
    Auth(AuthCommand),
    /// Health checks
    Health,
    /// API documentation helpers
    Docs(DocsCommand),
    /// Model metadata and schema management
    Describe(DescribeCommand),
    /// Model data operations
    Data(DataCommand),
    /// Advanced query operations
    Find(FindCommand),
    /// Aggregate operations
    Aggregate(AggregateCommand),
    /// Multi-operation transactions
    Bulk(BulkCommand),
    /// Record ACL management
    Acls(AclsCommand),
    /// Record metadata
    Stat(StatCommand),
    /// Change tracking
    Tracked(TrackedCommand),
    /// Soft-delete and restore workflows
    Trashed(TrashedCommand),
    /// User and sudo workflows
    User(UserCommand),
    /// Scheduled process workflows
    Cron(CronCommand),
    /// Tenant filesystem workflows
    Fs(FsCommand),
    /// Dynamic app packages
    App(AppCommand),
}

#[derive(Args, Debug)]
pub struct PublicCommand {
    #[command(subcommand)]
    pub command: PublicSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum PublicSubcommand {
    /// Open the human-facing root document
    Root,
    /// Open the agent-facing root document
    Llms,
}

#[derive(Args, Debug)]
pub struct AuthCommand {
    #[command(subcommand)]
    pub command: AuthSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum AuthSubcommand {
    /// Log in to an existing tenant
    Login(AuthLoginCommand),
    /// Register a new tenant
    Register(AuthRegisterCommand),
    /// Refresh a token
    Refresh(AuthRefreshCommand),
    /// List tenants available for login
    Tenants,
}

#[derive(Args, Debug)]
pub struct AuthLoginCommand {
    /// Tenant name to authenticate against
    #[arg(long)]
    pub tenant: Option<String>,

    /// Tenant ID to authenticate against
    #[arg(long = "tenant-id")]
    pub tenant_id: Option<String>,

    /// Username or email for the local bootstrap login
    #[arg(long)]
    pub username: Option<String>,

    /// Override the requested response format
    #[arg(long)]
    pub format: Option<String>,
}

#[derive(Args, Debug)]
pub struct AuthRegisterCommand {
    /// Tenant name to register
    #[arg(long)]
    pub tenant: Option<String>,

    /// Username or email for the tenant owner
    #[arg(long)]
    pub username: Option<String>,

    /// Optional database name to provision
    #[arg(long)]
    pub database: Option<String>,

    /// Optional tenant description
    #[arg(long)]
    pub description: Option<String>,

    /// Optional database adapter
    #[arg(long)]
    pub adapter: Option<String>,
}

#[derive(Args, Debug)]
pub struct AuthRefreshCommand {
    /// Refresh token to exchange; defaults to the saved token
    #[arg(long)]
    pub token: Option<String>,
}

#[derive(Args, Debug)]
pub struct DocsCommand {
    #[command(subcommand)]
    pub command: DocsSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum DocsSubcommand {
    /// Open the API overview
    Root,
    /// Open a docs path directly
    Path { path: Option<String> },
}

#[derive(Args, Debug)]
pub struct DescribeCommand {
    #[command(subcommand)]
    pub command: DescribeSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum DescribeSubcommand {
    List,
    Get(ModelArg),
    Create(ModelArg),
    Update(ModelArg),
    Delete(ModelArg),
    Fields(DescribeFieldsCommand),
}

#[derive(Args, Debug)]
pub struct DescribeFieldsCommand {
    #[command(subcommand)]
    pub command: DescribeFieldsSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum DescribeFieldsSubcommand {
    List(ModelArg),
    BulkCreate(ModelArg),
    BulkUpdate(ModelArg),
    Get(FieldArg),
    Create(FieldArg),
    Update(FieldArg),
    Delete(FieldArg),
}

#[derive(Args, Debug, Default, Clone)]
pub struct DataOptions {
    /// Include soft-deleted records
    #[arg(long)]
    pub include_trashed: bool,

    /// Include permanently deleted records
    #[arg(long)]
    pub include_deleted: bool,

    /// Remove the success envelope from responses
    #[arg(long)]
    pub unwrap: bool,

    /// Select a comma-separated field list
    #[arg(long)]
    pub select: Option<String>,

    /// Apply a JSON where filter
    #[arg(long = "where")]
    pub r#where: Option<String>,

    /// Exclude timestamp fields
    #[arg(long, value_parser = clap::builder::BoolishValueParser::new())]
    pub stat: Option<bool>,

    /// Exclude ACL fields
    #[arg(long, value_parser = clap::builder::BoolishValueParser::new())]
    pub access: Option<bool>,

    /// Perform permanent delete
    #[arg(long)]
    pub permanent: bool,

    /// Enable upsert mode for creates
    #[arg(long)]
    pub upsert: bool,
}

#[derive(Args, Debug)]
pub struct DataCommand {
    #[command(flatten)]
    pub options: DataOptions,

    #[command(subcommand)]
    pub command: DataSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum DataSubcommand {
    /// List records for a model via GET /api/data/:model
    List(ModelArg),
    /// Create one or more records via POST /api/data/:model
    Create(ModelArg),
    /// Bulk update records by id via PUT /api/data/:model
    Update(ModelArg),
    /// Bulk update records by filter via PATCH /api/data/:model
    Patch(ModelArg),
    /// Soft delete records via DELETE /api/data/:model
    Delete(ModelArg),
    /// Fetch a single record via GET /api/data/:model/:id
    Get(RecordArg),
    /// Update a single record via PUT /api/data/:model/:id
    Put(RecordArg),
    /// Patch a single record via PATCH /api/data/:model/:id
    #[command(name = "patch-record")]
    PatchRecord(RecordArg),
    /// Soft delete a single record via DELETE /api/data/:model/:id
    DeleteRecord(RecordArg),
    /// Work with owned relationship routes under /api/data/:model/:id/:relationship
    Relationship(RelationshipArg),
}

#[derive(Args, Debug)]
pub struct RelationshipArg {
    pub model: String,
    pub id: String,
    pub relationship: String,
    #[command(subcommand)]
    pub command: RelationshipSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum RelationshipSubcommand {
    /// List child records via GET /api/data/:model/:id/:relationship
    Get,
    /// Create a child record via POST /api/data/:model/:id/:relationship
    Create,
    /// Bulk update child records via PUT /api/data/:model/:id/:relationship
    Update,
    /// Soft delete child records via DELETE /api/data/:model/:id/:relationship
    Delete,
    /// Address a specific nested child record
    Child(RelationshipChildCommand),
}

#[derive(Args, Debug)]
pub struct RelationshipChildCommand {
    pub child: String,
    #[command(subcommand)]
    pub command: RelationshipChildSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum RelationshipChildSubcommand {
    /// Fetch a nested child record via GET /api/data/:model/:id/:relationship/:child
    Get,
    /// Update a nested child record via PUT /api/data/:model/:id/:relationship/:child
    Put,
    /// Patch a nested child record via PATCH /api/data/:model/:id/:relationship/:child
    Patch,
    /// Soft delete a nested child record via DELETE /api/data/:model/:id/:relationship/:child
    Delete,
}

#[derive(Args, Debug, Default, Clone)]
pub struct FindOptions {
    /// Project a comma-separated field list
    #[arg(long)]
    pub select: Option<String>,

    /// Apply a JSON where filter from stdin, a file (@path), or inline JSON
    #[arg(long = "where")]
    pub r#where: Option<String>,

    /// Apply a comma-separated order list
    #[arg(long)]
    pub order: Option<String>,

    /// Limit the number of returned records
    #[arg(long)]
    pub limit: Option<u32>,

    /// Skip the first N matching records
    #[arg(long)]
    pub offset: Option<u32>,
}

#[derive(Args, Debug)]
pub struct FindCommand {
    #[command(flatten)]
    pub options: FindOptions,

    #[command(subcommand)]
    pub command: FindSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum FindSubcommand {
    Query(ModelArg),
    Saved(FindSavedArg),
}

#[derive(Args, Debug)]
pub struct FindSavedArg {
    pub model: String,
    pub target: String,
}

#[derive(Args, Debug, Default, Clone)]
pub struct AggregateOptions {
    /// Count all records
    #[arg(long)]
    pub count: bool,

    /// Sum of field values
    #[arg(long)]
    pub sum: Option<String>,

    /// Average of field values
    #[arg(long)]
    pub avg: Option<String>,

    /// Minimum field value
    #[arg(long)]
    pub min: Option<String>,

    /// Maximum field value
    #[arg(long)]
    pub max: Option<String>,

    /// Apply a JSON where filter from stdin, a file (@path), or inline JSON
    #[arg(long = "where")]
    pub r#where: Option<String>,

    /// Full POST body from stdin, a file (@path), or inline JSON
    #[arg(long)]
    pub body: Option<String>,
}

#[derive(Args, Debug)]
pub struct AggregateCommand {
    #[command(flatten)]
    pub options: AggregateOptions,

    #[command(subcommand)]
    pub command: AggregateSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum AggregateSubcommand {
    Get(ModelArg),
    Run(ModelArg),
}

#[derive(Args, Debug, Default, Clone)]
pub struct BulkOptions {
    /// JSON body from stdin, a file (@path), or inline JSON
    #[arg(long)]
    pub body: Option<String>,
}

#[derive(Args, Debug)]
pub struct BulkCommand {
    #[command(flatten)]
    pub options: BulkOptions,

    #[command(subcommand)]
    pub command: BulkSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum BulkSubcommand {
    /// Execute an arbitrary bulk payload
    Run,
    /// Create many records in one model
    Create(ModelArg),
    /// Update many records in one model
    Update(ModelArg),
    /// Delete many records in one model
    Delete(ModelArg),
    Export,
    Import,
}

#[derive(Args, Debug)]
pub struct AclsCommand {
    #[command(subcommand)]
    pub command: AclsSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum AclsSubcommand {
    Get(RecordArg),
    Create(RecordArg),
    Update(RecordArg),
    Delete(RecordArg),
}

#[derive(Args, Debug)]
pub struct StatCommand {
    #[command(subcommand)]
    pub command: StatSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum StatSubcommand {
    Get(RecordArg),
}

#[derive(Args, Debug)]
pub struct TrackedCommand {
    #[command(subcommand)]
    pub command: TrackedSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum TrackedSubcommand {
    List(RecordArg),
    Get(TrackedRecordArg),
}

#[derive(Args, Debug)]
pub struct TrashedCommand {
    #[command(subcommand)]
    pub command: TrashedSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum TrashedSubcommand {
    List,
    Model(TrashedModelArg),
    Record(RecordArg),
}

#[derive(Args, Debug)]
pub struct UserCommand {
    #[command(subcommand)]
    pub command: UserSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum UserSubcommand {
    Me,
    List(UserListCommand),
    Create(UserCreateCommand),
    Get(UserIdArg),
    Update(UserIdArg),
    Delete(UserDeleteCommand),
    Password(UserPasswordCommand),
    Keys(UserKeysCommand),
    Sudo(UserSudoCommand),
    Fake(UserFakeCommand),
}

#[derive(Args, Debug, Default)]
pub struct UserListCommand {
    /// Maximum number of records to return
    #[arg(long)]
    pub limit: Option<u32>,

    /// Number of records to skip
    #[arg(long)]
    pub offset: Option<u32>,
}

#[derive(Args, Debug)]
pub struct UserCreateCommand {
    /// JSON body from stdin or use --body to inline it
    #[arg(long)]
    pub body: Option<String>,

    /// Optional name
    #[arg(long)]
    pub name: Option<String>,

    /// Optional auth identifier
    #[arg(long)]
    pub auth: Option<String>,

    /// Optional access level
    #[arg(long)]
    pub access: Option<String>,
}

#[derive(Args, Debug)]
pub struct UserDeleteCommand {
    pub id: String,

    /// Explicitly confirm self-deactivation
    #[arg(long)]
    pub confirm: bool,

    /// Optional audit-trail reason
    #[arg(long)]
    pub reason: Option<String>,
}

#[derive(Args, Debug)]
pub struct UserPasswordCommand {
    pub id: String,

    /// Current password when changing your own password
    #[arg(long = "current-password")]
    pub current_password: Option<String>,

    /// New password to set
    #[arg(long = "new-password")]
    pub new_password: Option<String>,
}

#[derive(Args, Debug)]
pub struct UserKeysCommand {
    #[command(subcommand)]
    pub command: UserKeysSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum UserKeysSubcommand {
    List(UserIdArg),
    Create(UserKeysCreateCommand),
    Delete(UserKeyDeleteCommand),
}

#[derive(Args, Debug)]
pub struct UserKeysCreateCommand {
    pub id: String,

    /// Friendly name for the API key
    #[arg(long)]
    pub name: Option<String>,

    /// Environment to generate the key for
    #[arg(long)]
    pub environment: Option<String>,

    /// Raw JSON permissions object
    #[arg(long)]
    pub permissions: Option<String>,

    /// ISO 8601 expiration timestamp
    #[arg(long = "expires-at")]
    pub expires_at: Option<String>,
}

#[derive(Args, Debug)]
pub struct UserKeyDeleteCommand {
    pub id: String,
    pub key_id: String,
}

#[derive(Args, Debug)]
pub struct UserSudoCommand {
    /// Audit-trail reason for the elevation
    #[arg(long)]
    pub reason: Option<String>,
}

#[derive(Args, Debug)]
pub struct UserFakeCommand {
    /// Target user ID to impersonate
    #[arg(long = "user-id")]
    pub user_id: Option<String>,

    /// Target username to impersonate
    #[arg(long)]
    pub username: Option<String>,
}

#[derive(Args, Debug)]
pub struct CronCommand {
    #[command(subcommand)]
    pub command: CronSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum CronSubcommand {
    List,
    Create,
    Get(CronIdArg),
    Update(CronIdArg),
    Delete(CronIdArg),
    Enable(CronIdArg),
    Disable(CronIdArg),
}

#[derive(Args, Debug)]
pub struct FsCommand {
    #[command(subcommand)]
    pub command: FsSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum FsSubcommand {
    Get(PathArg),
    Put(PathArg),
    Delete(PathArg),
}

#[derive(Args, Debug)]
pub struct AppCommand {
    pub app_name: String,
    pub path: Option<String>,
}

#[derive(Args, Debug, Clone)]
pub struct ModelArg {
    pub model: String,
}

#[derive(Args, Debug, Clone)]
pub struct FieldArg {
    pub model: String,
    pub field: String,
}

#[derive(Args, Debug, Clone)]
pub struct RecordArg {
    pub model: String,
    pub id: String,
}

#[derive(Args, Debug, Clone)]
pub struct TrackedRecordArg {
    pub model: String,
    pub id: String,
    pub change: String,
}

#[derive(Args, Debug, Clone)]
pub struct TrashedModelArg {
    pub model: String,
}

#[derive(Args, Debug, Clone)]
pub struct UserIdArg {
    pub id: String,
}

#[derive(Args, Debug, Clone)]
pub struct CronIdArg {
    pub pid: String,
}

#[derive(Args, Debug, Clone)]
pub struct PathArg {
    pub path: String,
}
