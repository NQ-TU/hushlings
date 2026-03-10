# Autonomous Agents Project Proposal

## Hushlings: A Social Artificial Life Swarm

### 1. Project Overview

This project will implement a small population of autonomous artificial creatures called **Hushlings**, designed to behave like a strange/unfamiliar social species with their own emotional states and subsequent emergent group behaviour.

Each creature will operate as an independent agent with internal needs and emotions such as fear, curiosity, confidence, and loneliness. These internal states will influence their behaviour and decision making, allowing the creatures to pursure goals autonomously.

Individually, each Hushling behave timidly and attempt to avoid the player while searching for others of their kind. However, as their local swarm grows, their behaviour changes. Small groups may cautiosuly observe the player, while larger groups become increasingly confident, eventually circling and surrounding the player with coordinated swarm behaviour.

The aim of the project is to create a convincing artificial lifeform that appears aware, curious, and socially intelligent, however abstract enough from our regular social norms that the user will feel out of place, as if they were dropped onto a different planet. Through movement, gaze behaviour, and subtle sound cues, the the creatures will slowly manipulate the user into feeling that they are the entity being observed rather than the observer.

### 2. Creature Identity and Personality

**Species Name**: Hushlings

**Behavioural Traits**: They will be designed to behave like a shy and social species, with the following traits:

- Timid when alone
- Curious observers of the player
- Social and dependent on nearby creatures (e.g., will group with other Hushlings)
- Confidence increases in larger groups (e.g., more observant and less timid of players presence)
- However, easily startled by player movement or attention in low confidence states (e.g., by itself, the users gaze will make it 'flee' or avoid, however in a group or high confidence state, it will be less likely to flee, and perhaps use a 'defence' state, such as growing in size, color, or creating noises to intimidate)

I hope to create an unsettling enviornment that slowly emerges the more our user becomes immersed in the game. They will watch, regroup, and move together, creating an impression of collective intelligence. Over time, the player may begin to feel as though they are losing their position of control within the environment, becoming the subject of observation rather than the dominant agent

### 3. Core Behaviour Concept

The primary idea of the project is confidence driven by swarm size. Each creature will adjust its behaviour based on:

- It's distance from the player
- Number of nearby creatures
- Whether the player is looking directly at them
- It's internal emotional state (e.g., did it flee recently, dropping its confidence? It's likely to have a higher regroup drive and higher flee response again then until confidence rises.)

An important behavioural mechanic is that Hushlings behave differently depending on whether the player is directly observing them. When the player looks at them, they tend to become timid, freeze, or retreat. When the player looks away, they may cautiously move closer or regroup. This creates the unsettling feeling that the creatures are acting when the player is not watching.

These simple rules allow emergent behaviour to arise within the swarm. Over time, individual creatures may develop slightly different behaviour patterns depending on their confidence levels, creating unexpected outliers that challenge the player’s assumptions about how the swarm behaves.

**Behaviour Progression**

_Alone_

- Wanders and searches for other creatures, confidence slowly rises without interaction
- Avoids the player
- Occasionally observes from a distance

_Small Group (2/3)_

- Will catiously observe the user, more frequently
- Lingers a bit longer, doesn't immediately break gaze or flee from user gaze
- Swarmed creatures mirror behaviour of other in group. e.g., if one is observing, then others will join.

_Medium Group (4/5)_

- Will circle the player
- Occasionally approach the player (keeping distance)
- Probing and 'chatter' e.g., the player is approached by one which quickly returns, and 'gossips' with the others

_Large Group (5+)_

- Will surround player
- Moves as a loosely coordinated group (more confidence, less timidness)
- Maintain collective attention, user can break this through aggressive actions

I hope this creates a sense that the creatures are slowly learning about the player, together.

### 4. Emotional System and Autonomous Needs (Internal Variables)

Each creature will maintain internal variables that influence their behavior.

- Fear: Increases when the player approaches or stares directly.
- Curiosity: Increases when the player is still or 'passive'
- Confidence: Increases when other creatures are nearby
- Loneliness: Increases when isolated
- Energy: Influences idle behaviour and movement

These variables will determine the creatures current goal and state transitions, e.g., will it attempt to:

- Regroup with other creatures
- Maintain safe distnace from the player
- Observe the player
- Catiously approach the player
- Retreat or flee
- Participate in swarm behaviour

This system allows each creature to make decisions independently while still contributing to collective swarm dynamics.

### 5. Visual and Audio Design

The visual design will evolve alongside the creatures behaviour. Early in the simulation the creatures appear as soft, amorphous shapes with simple rounded forms. As they observe the player and gather into larger swarms, their bodies gradually become more structured, slowly adopting human silhouettes. This transformation reflects the idea that the creatures are studying and mimicking the player.

The goal is to create an uncanny progression from harmless blob like organisms to strange humanoid observers. The creatures will remain stylised and low poly to maintain a consistent aesthetic while still conveying subtle changes in posture and form.

Lighting and atmosphere will play an important role in establishing mood. A dark environment with soft fog, subtle glow effects, and restrained colour palettes will help focus attention on the creatures and their movement.

Sound design will reinforce their emotional behaviour. Small ambient sounds such as quiet murmurs, clicks, or breath like tones will accompany movement and swarm activity. As more creatures gather, these sounds will layer together into a subtle collective ambience, enhancing the impression that the creatures are communicating or reacting socially.

### 6. Technical Approach

The creatures will be implemented as independent agents within the Godot engine. Each agent will maintain internal emotional variables such as fear, curiosity, confidence, and loneliness. These variables influence the creature’s current goal and behaviour state.

A Finite State Machine will control high level behaviours such as roaming, observing the player, approaching cautiously, circling, fleeing, and participating in swarm behaviour. Movement will be implemented using steering behaviours, allowing creatures to move smoothly through the environment while avoiding obstacles and maintaining group cohesion.

Swarm behaviour will emerge from simple local rules based on nearby creatures, inspired by Boids-style flocking algorithms such as separation, cohesion, and alignment. Procedural animation techniques such as idle hovering, subtle body motion, and head or eye tracking will help make the creatures appear more lifelike.

The project will be structured using several scripts with clear responsibilities, separating perception, behaviour logic, movement, and animation systems.

### 7. Summary

This project explores the idea of a small artificial species whose behaviour emerges from simple emotional states and social interactions. Individually the creatures are timid and avoid the player, but together they gain confidence and begin to observe, approach, and eventually surround the player as a coordinated swarm.

By combining autonomous agents, swarm behaviour, procedural animation, and responsive sound design, the project aims to create the illusion of a living digital ecosystem. The creatures are not intended to behave as traditional enemies, but rather as a curious artificial species that appears to study and react to the player in believable and unsettling ways.
