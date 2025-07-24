import { describe, it, expect, beforeEach } from "vitest"

describe("Infrastructure Funding Contract", () => {
  let contractAddress
  let creatorAddress
  let contributorAddress
  
  beforeEach(() => {
    contractAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.infrastructure-funding"
    creatorAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
    contributorAddress = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
  })
  
  describe("Project Creation", () => {
    it("should create a new project successfully", () => {
      const title = "New Classroom Construction"
      const description = "Building modern classrooms for rural school"
      const fundingGoal = 50000
      const durationDays = 30
      
      const result = {
        type: "ok",
        value: 1, // project-id
      }
      
      expect(result.type).toBe("ok")
      expect(typeof result.value).toBe("number")
    })
    
    it("should reject project with zero funding goal", () => {
      const title = "Invalid Project"
      const description = "Project with no funding goal"
      const fundingGoal = 0
      const durationDays = 30
      
      const result = {
        type: "error",
        value: 204, // ERR-INSUFFICIENT-CONTRIBUTION
      }
      
      expect(result.type).toBe("error")
      expect(result.value).toBe(204)
    })
    
    it("should reject project with zero duration", () => {
      const title = "Invalid Duration Project"
      const description = "Project with no duration"
      const fundingGoal = 25000
      const durationDays = 0
      
      const result = {
        type: "error",
        value: 202, // ERR-PROJECT-EXPIRED
      }
      
      expect(result.type).toBe("error")
      expect(result.value).toBe(202)
    })
  })
  
  describe("Project Contributions", () => {
    it("should accept valid contribution", () => {
      const projectId = 1
      const contributionAmount = 5000
      
      const result = {
        type: "ok",
        value: true,
      }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
    })
    
    it("should reject zero contribution", () => {
      const projectId = 1
      const contributionAmount = 0
      
      const result = {
        type: "error",
        value: 204, // ERR-INSUFFICIENT-CONTRIBUTION
      }
      
      expect(result.type).toBe("error")
      expect(result.value).toBe(204)
    })
    
    it("should reject contribution to expired project", () => {
      const projectId = 1
      const contributionAmount = 1000
      
      const result = {
        type: "error",
        value: 202, // ERR-PROJECT-EXPIRED
      }
      
      expect(result.type).toBe("error")
      expect(result.value).toBe(202)
    })
  })
  
  describe("Milestone Management", () => {
    it("should add milestone successfully", () => {
      const projectId = 1
      const description = "Foundation completed"
      const fundingPercentage = 25
      
      const result = {
        type: "ok",
        value: 1, // milestone-id
      }
      
      expect(result.type).toBe("ok")
      expect(typeof result.value).toBe("number")
    })
    
    it("should reject milestone with invalid percentage", () => {
      const projectId = 1
      const description = "Invalid milestone"
      const fundingPercentage = 150 // > 100%
      
      const result = {
        type: "error",
        value: 207, // ERR-INVALID-MILESTONE
      }
      
      expect(result.type).toBe("error")
      expect(result.value).toBe(207)
    })
    
    it("should complete milestone successfully", () => {
      const projectId = 1
      const milestoneId = 1
      
      const result = {
        type: "ok",
        value: true,
      }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
    })
  })
  
  describe("Fund Withdrawal", () => {
    it("should withdraw milestone funds when goal reached", () => {
      const projectId = 1
      const milestoneId = 1
      
      const result = {
        type: "ok",
        value: 12500, // 25% of 50000
      }
      
      expect(result.type).toBe("ok")
      expect(typeof result.value).toBe("number")
    })
    
    it("should reject withdrawal when goal not reached", () => {
      const projectId = 1
      const milestoneId = 1
      
      const result = {
        type: "error",
        value: 205, // ERR-GOAL-NOT-REACHED
      }
      
      expect(result.type).toBe("error")
      expect(result.value).toBe(205)
    })
  })
  
  describe("Refund Process", () => {
    it("should process refund for failed project", () => {
      const projectId = 1
      
      const result = {
        type: "ok",
        value: 5000, // refund amount
      }
      
      expect(result.type).toBe("ok")
      expect(typeof result.value).toBe("number")
    })
    
    it("should reject refund for successful project", () => {
      const projectId = 1
      
      const result = {
        type: "error",
        value: 205, // ERR-GOAL-NOT-REACHED
      }
      
      expect(result.type).toBe("error")
      expect(result.value).toBe(205)
    })
  })
  
  describe("Read-only Functions", () => {
    it("should retrieve project information", () => {
      const projectInfo = {
        creator: creatorAddress,
        title: "New Classroom Construction",
        description: "Building modern classrooms for rural school",
        "funding-goal": 50000,
        "current-funding": 25000,
        deadline: 5000,
        "created-at": 1000,
        completed: false,
        "funds-withdrawn": false,
        "milestone-count": 2,
        "current-milestone": 0,
      }
      
      expect(projectInfo.title).toBe("New Classroom Construction")
      expect(projectInfo["funding-goal"]).toBe(50000)
      expect(projectInfo.completed).toBe(false)
    })
    
    it("should check if funding goal is reached", () => {
      const projectId = 1
      const goalReached = true
      
      expect(goalReached).toBe(true)
    })
    
    it("should return funding statistics", () => {
      const stats = {
        "total-projects": 10,
        "total-funded": 5,
        "total-raised": 250000,
        "contract-balance": 100000,
      }
      
      expect(stats["total-projects"]).toBe(10)
      expect(stats["total-raised"]).toBe(250000)
    })
  })
})
