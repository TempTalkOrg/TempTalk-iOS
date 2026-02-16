@file:MavenRepository("inner-repo", "https://raw.githubusercontent.com/difftim/AndroidRepo/main")
@file:DependsOn("wu.seal:kscript-tool:1.1.22")
@file:CompilerOpts("-jvm-target 9")

import java.net.URLEncoder


private val appPackageBot = WeaBot("https:///\$GITHUB_PASSWORD_DIFFT@raw.githubusercontent.com/difftim/Secrets/main/DifftAppPackageBot")

val notifyGroupId = "a7e09a2c4e8a46d68c5eb596a39a717b"
val testGroup = "b7289029e6fa40f68f4942b3e00e045f"
val PR_URL = args[0].trim()
val PR_TITLE = args[1].trim()
val MENTIONED_USERS = args[2].trim()
val REVIEWERS = args[3].trim()
val TEAM_REVIEWERS = args[4].trim()
val PR_CREATOR = args[5].trim()

val nameMap = mapOf(
    "jiangcanming" to "Jaymin(cc)",
    "Henry-yhz" to "Henry(cc)",
    "kaitopic" to "Ethan(cc)",
    "krisDev000" to "Kris(cc)",
    "small3flower" to "Felix(cc)",
    "kitty22520" to "Neo (cc)",
    "wuseal" to "King (cc)",
    "Suosuo123" to "Nate(cc)",
    "binghuan" to "Wayne.l (cc)",
    "frontend-iOS" to "All",
    "frontend-Android" to "All"
    )

val team_nameMap = mapOf(
    "jiangcanming" to "Jaymin(cc)",
    "Henry-yhz" to "Henry(cc)",
    "kaitopic" to "Ethan(cc)",
    "krisDev000" to "Kris(cc)",
    "small3flower" to "Felix(cc)",
    "kitty22520" to "Neo (cc)",
    "wuseal" to "King (cc)",
    "Suosuo123" to "Nate(cc)",
    "binghuan" to "Wayne.l (cc)",
    "frontend-iOS" to "All(Android)",
    "frontend-Android" to "All(iOS)"
    )

val ccIdMap = mapOf(
    "jiangcanming" to "+74369980051",
    "Henry-yhz" to "+75550788910",
    "kaitopic" to "+77613441589",
    "krisDev000" to "+74245256575",
    "small3flower" to "+78789346691",
    "kitty22520" to "+79953995471",
    "wuseal" to "+73722913891",
    "Suosuo123" to "+79099100519",
    "binghuan" to "+77971630878",
    "frontend-iOS" to "all",
    "frontend-Android" to "all"
    )
val finalReviewerGithubNames = (MENTIONED_USERS.split(" ").map { it.trim().drop(1) } + REVIEWERS.split(" ").map { it.trim() } + TEAM_REVIEWERS.split(" ").map { it.trim() }).filterNot { it.isBlank() }.toSet()
//appPackageBot.sendMessageToGroup(testGroup, args.toList().toString() + "\n$finalReviewerGithubNames")

val prNotifyContent = """
    #### $PR_TITLE
    ---------
    **PR Link**: $PR_URL
    
    **Created by**: [${nameMap[PR_CREATOR]}](wea://localAction/thread?tid=${URLEncoder.encode(ccIdMap[PR_CREATOR].toString())})

    **Requested Reviewers**:
    ${finalReviewerGithubNames.joinToString(" ") { "[@${nameMap[it]}](wea://localAction/thread?tid=${URLEncoder.encode(ccIdMap[it].toString())})" }}
""".trimIndent()
appPackageBot.sendMarkdownMessageToGroup(notifyGroupId,prNotifyContent, (finalReviewerGithubNames.mapNotNull { ccIdMap[it] } + ccIdMap[PR_CREATOR]).filterNotNull())