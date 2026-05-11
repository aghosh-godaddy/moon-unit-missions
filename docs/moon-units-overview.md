# Moon Units — Explained Simply

Imagine you have a robot helper that can write code for you. But instead of sitting next to you and typing on your keyboard, this robot lives inside a little bubble (a Docker container) where it gets its own copy of your code, does its work, and hands back the result.

**Moon Units is a system that tells the robot what to do, gives it a workspace, and delivers the finished work back to you.**

## Concepts

| Moon Units concept | Like... |
|---|---|
| **Stage** | One chore on a chore list ("clean your room") — a single prompt/instruction for the AI |
| **Plan** | The whole chore list in order ("clean room, then do dishes, then take out trash") |
| **Manifest** | The note on the fridge that says *which* chores, *which* house (repo), and *when* to start |
| **Mission** | Actually doing the chores — one complete run from start to finish |
| **Trigger** | The thing that says "GO!" — like a Jira ticket getting a label, or a PR getting a review comment |

## The Flow

1. Something happens (e.g., you label a Jira ticket `fix-this`)
2. Moon Units notices and spins up a fresh, isolated bubble (Docker container)
3. Inside the bubble, it clones your repo, gives the AI (Claude) the instructions from your manifest
4. The AI does the work — writes code, opens a PR, writes a design doc, whatever the stages say
5. The bubble pops (gets deleted) — clean, no mess left behind

## Why It Exists

Instead of every developer manually opening Claude Code, copy-pasting context, and babysitting the AI through a task, Moon Units lets you **define the work once as a recipe (manifest)** and then it runs automatically whenever the trigger fires. It's like going from hand-washing every dish to loading a dishwasher — you describe what needs cleaning, press start, and walk away.

## The Key Parts of the Platform

- **`mu` CLI** — the command-line tool you run locally to launch or watch for missions
- **Moon Unit API** — the brain that tracks plans, manifests, and missions
- **Moon Unit Control** — the live wire that streams logs and lets you send commands
- **Moon Unit GitHub** — handles talking to GitHub on behalf of the platform
- **Moon Unit UI** — a web dashboard to see what missions ran and what happened

## In One Sentence

**Moon Units is GoDaddy's internal platform that automatically runs AI coding agents in disposable containers, triggered by events like Jira tickets or PR reviews, so teams can delegate repetitive coding tasks to AI without babysitting it.**
