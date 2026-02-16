@file:MavenRepository("inner-repo", "https://raw.githubusercontent.com/difftim/AndroidRepo/main")
@file:DependsOn("wu.seal:kscript-tool:1.1.22")
@file:DependsOn("com.squareup.retrofit2:retrofit:2.9.0")
@file:DependsOn("com.squareup.retrofit2:converter-gson:2.9.0")
@file:DependsOn("com.squareup.okhttp3:logging-interceptor:4.9.1")
@file:CompilerOpts("-jvm-target 9")

import retrofit2.Call
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import java.net.URLEncoder
import java.util.regex.Pattern

// --- GitHub API Related Setup ---
data class GitHubUser(
    val login: String
)

data class PullRequest(
    val title: String?,
    val body: String?,
    val requested_reviewers: List<GitHubUser>?
)

interface GitHubApiService {
    @GET("repos/{owner}/{repo}/pulls/{pull_number}")
    fun getPullRequestDetails(
        @Path("owner") owner: String = "difftim",
        @Path("repo") repo: String = "TempTalk-iOS",
        @Path("pull_number") pullNumber: Int
    ): Call<PullRequest>
}

val enableHttpLogging = System.getenv("RUNNER_DEBUG") == "1"

val httpClient = OkHttpClient.Builder().apply {
    if (enableHttpLogging) {
        val logging = HttpLoggingInterceptor(HttpLoggingInterceptor.Logger { message -> println("OkHttp: $message") })
        logging.setLevel(HttpLoggingInterceptor.Level.BODY)
        addInterceptor(logging)
    }
    addInterceptor { chain ->
        val original = chain.request()
        val requestBuilder = original.newBuilder()
        val githubToken = System.getenv("GITHUB_PASSWORD_DIFFT")
        if (!githubToken.isNullOrEmpty()) {
            requestBuilder.header("Authorization", "token $githubToken")
        } else {
            println("Warning: GITHUB_PASSWORD_DIFFT token not found in environment variables.")
        }
        val request = requestBuilder.method(original.method, original.body).build()
        chain.proceed(request)
    }
}.build()

val retrofit = Retrofit.Builder()
    .baseUrl("https://api.github.com/")
    .addConverterFactory(GsonConverterFactory.create())
    .client(httpClient)
    .build()

val githubService = retrofit.create(GitHubApiService::class.java)
// --- End GitHub API Setup ---

// Read initial PR details from environment variables
val ENV_PR_URL = System.getenv("ENV_PR_URL") ?: ""
val ENV_PR_CREATOR = System.getenv("ENV_PR_CREATOR") ?: "Unknown Creator"
val ENV_PR_NUMBER_STR = System.getenv("ENV_PR_NUMBER")
val PR_NUMBER = ENV_PR_NUMBER_STR?.toIntOrNull()

// Function to extract @mentions from PR body
fun extractMentionsFromText(text: String?): Set<String> {
    if (text.isNullOrBlank()) return emptySet()
    val pattern = Pattern.compile("@([a-zA-Z0-9_-]+)")
    val matcher = pattern.matcher(text)
    val mentions = mutableSetOf<String>()
    while (matcher.find()) {
        mentions.add(matcher.group(1)) // group(1) is the username without @
    }
    return mentions
}

private val appPackageBot = WeaBot("https:///\$GITHUB_PASSWORD_DIFFT@raw.githubusercontent.com/difftim/Secrets/main/DifftAppPackageBot")
val notifyGroupId = "a7e09a2c4e8a46d68c5eb596a39a717b"

val nameMap = mapOf(
    "Henry-yhz" to "Henry(cc)",
    "krisDev000" to "Kris(cc)",
    "small3flower" to "Felix(cc)"
)

val ccIdMap = mapOf(
    "Henry-yhz" to "+75550788910",
    "krisDev000" to "+74245256575",
    "small3flower" to "+78789346691"
)

fun fetchFullPrDetails(prNumber: Int): PullRequest? {
    println("Fetching full PR details for PR #$prNumber...")
    try {
        val response = githubService.getPullRequestDetails(pullNumber = prNumber).execute()
        if (response.isSuccessful) {
            val prDetails = response.body()
            println("Successfully fetched full PR details from API.")
            println("PR Details: Title='${prDetails?.title}', Body='${prDetails?.body?.take(100)}...', Reviewers='${prDetails?.requested_reviewers?.map { it.login }}'")
            return prDetails
        } else {
            println("Error fetching full PR details from API: ${response.code()} - ${response.message()}")
            println("Response body: ${response.errorBody()?.string()}")
        }
    } catch (e: Exception) {
        println("Exception while fetching full PR details from API: ${e.message}")
        e.printStackTrace()
    }
    return null
}

fun main() {
    println("PR Notification Script Started.")
    println("Initial ENV_PR_URL: $ENV_PR_URL")
    println("Initial ENV_PR_CREATOR: $ENV_PR_CREATOR")
    println("Initial ENV_PR_NUMBER: $PR_NUMBER (raw string: '$ENV_PR_NUMBER_STR')")

    if (PR_NUMBER == null) {
        println("Error: ENV_PR_NUMBER is not set or invalid. Cannot proceed.")
        return
    }

    println("Waiting for 60 seconds to allow for PR updates...")
    try {
        Thread.sleep(60000) // 60 seconds
    } catch (ie: InterruptedException) {
        println("Delay interrupted: ${ie.message}")
        Thread.currentThread().interrupt()
    }
    println("Delay finished.")

    val currentPrDetails = fetchFullPrDetails(PR_NUMBER)

    if (currentPrDetails == null) {
        println("Error: Failed to fetch current PR details after delay. Cannot send notification.")
        return
    }

    val PR_TITLE = currentPrDetails.title ?: "PR Title Not Found (Post-Fetch)"
    val PR_BODY = currentPrDetails.body ?: ""
    val mentionedUserLogins = extractMentionsFromText(PR_BODY)
    println("Extracted mentioned user logins from PR body (post-delay): $mentionedUserLogins")

    val requestedReviewerLogins = currentPrDetails.requested_reviewers?.map { it.login }?.toSet() ?: emptySet()
    println("Fetched Requested Reviewers (post-delay): $requestedReviewerLogins")

    // Combine and then filter against known users to prevent inclusion of non-username mentions like "@mentions"
    val allPotentialLogins = (mentionedUserLogins + requestedReviewerLogins)
        .filterNot { it.isBlank() }
        .toSet()
    println("All potential logins (mentioned + API reviewers) before filtering: $allPotentialLogins")

    val finalReviewerGithubNames = allPotentialLogins
        .filter { nameMap.containsKey(it) || ccIdMap.containsKey(it) } // Ensure user is known
        .toSet()
    println("Final combined reviewer/mentioned GitHub usernames (after filtering by known users): $finalReviewerGithubNames")

    val prNotifyContent = """
        #### $PR_TITLE
        ---------
        **PR Link**: $ENV_PR_URL
        
        **Created by**: [${nameMap[ENV_PR_CREATOR] ?: ENV_PR_CREATOR}](wea://localAction/thread?tid=${URLEncoder.encode(ccIdMap[ENV_PR_CREATOR].toString())})

        **Reviewers/Mentioned**:
        ${finalReviewerGithubNames.joinToString(" ") { "[@${nameMap[it] ?: it}](wea://localAction/thread?tid=${URLEncoder.encode(ccIdMap[it].toString())})" }}
    """.trimIndent()

    val ccReceivers = (finalReviewerGithubNames.mapNotNull { ccIdMap[it] } + ccIdMap[ENV_PR_CREATOR])
        .filterNotNull()
        .toSet()
    println("Final CC receiver IDs: $ccReceivers")

    if (finalReviewerGithubNames.isEmpty() && nameMap[ENV_PR_CREATOR] == null && ccIdMap[ENV_PR_CREATOR] == null) {
        println("No known reviewers/mentioned users or creator to notify. Skipping notification.")
    } else {
        println("Sending notification with content:\n$prNotifyContent")
        appPackageBot.sendMarkdownMessageToGroup(notifyGroupId, prNotifyContent, ccReceivers.toList())
        println("Notification task submitted.")
    }
    println("PR Notification Script Finished.")
}

main()

